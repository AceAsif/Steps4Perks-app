import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; // Added for date formatting

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedDeviceId;

  // --- Device ID Management ---
  /// Retrieves a unique device ID. Caches it for subsequent calls.
  /// Provides unique fallbacks for non-physical devices/emulators.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android ID is generally unique to the device and app installation.
        _cachedDeviceId = androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // identifierForVendor is unique per app installation on iOS devices.
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'unknown-ios-vendor-${DateTime.now().millisecondsSinceEpoch}';
      } else {
        // For web, desktop, or other platforms/emulators where a stable hardware ID isn't available.
        // Using a timestamp to ensure a unique ID for each app session.
        _cachedDeviceId = 'unknown-platform-id-${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('⚠️ Running on an unexpected platform or simulator. Using a generated ID.');
      }
    } catch (e) {
      debugPrint('❌ Failed to retrieve device ID: $e');
      // Fallback in case of any error during device ID retrieval.
      _cachedDeviceId = 'error-device-retrieval-${DateTime.now().millisecondsSinceEpoch}';
    }

    // Final check to ensure the cached ID is not null or empty.
    if (_cachedDeviceId == null || _cachedDeviceId!.isEmpty) {
      _cachedDeviceId = 'default-fallback-id-${DateTime.now().millisecondsSinceEpoch}';
    }
    debugPrint('Device ID: $_cachedDeviceId'); // Log the device ID for debugging
    return _cachedDeviceId!;
  }

  // --- Helper for Consistent Document Paths ---

  /// Provides a consistent DocumentReference for daily stats for the current device.
  /// All daily statistic operations (save, update, get, delete) should use this helper
  /// to ensure data is stored and retrieved from the same location.
  /// Structure: `users/{deviceId}/dailyStats/{date}`
  Future<DocumentReference> _getDailyStatsDocRef(String date) async {
    final deviceId = await getDeviceId();
    return _firestore
        .collection('users') // Top-level collection for user/device data
        .doc(deviceId)       // Document representing the specific device/user
        .collection('dailyStats') // Subcollection for daily statistics documents
        .doc(date);          // Document for the specific date (e.g., '2025-07-24')
  }

  // --- Core Data Operations ---

  /// Saves or updates daily step statistics and total points for a specific date.
  /// Data is stored under the consistent path: `users/{deviceId}/dailyStats/{date}`.
  Future<void> saveStatsAndPoints({
    required String date,
    required int steps,
    required int dailyPointsEarned,
    required int streak,
    required int totalPoints,
    bool claimedDailyBonus = false,
  }) async {
    final docRef = await _getDailyStatsDocRef(date); // Use the consistent path helper

    final batch = _firestore.batch(); // Use a batch for atomic updates

    batch.set(docRef, {
      'date': date,
      'steps': steps,
      'dailyPointsEarned': dailyPointsEarned,
      'streak': streak,
      'totalPoints': totalPoints, // Store total points for consistency and easy retrieval
      'claimedDailyBonus': claimedDailyBonus, // Store the daily bonus claim status
      'lastUpdated': FieldValue.serverTimestamp(), // Timestamp of the last update
      // Add a dedicated timestamp field for range queries (e.g., for charts)
      'timestamp': Timestamp.fromDate(DateFormat('yyyy-MM-dd').parse(date)),
    }, SetOptions(merge: true)); // Merge to update existing fields without overwriting others

    try {
      await batch.commit(); // Commit all batched writes
      debugPrint('✅ saveStatsAndPoints: Batching complete for $date.');
    } catch (e, stack) {
      debugPrint('❌ saveStatsAndPoints failed: $e');
      debugPrint('Stack Trace: $stack');
      rethrow; // Re-throw the error to allow the caller to handle it
    }
  }

  /// Updates only the daily bonus claim status and total points for a specific date.
  /// Data is updated under the consistent path: `users/{deviceId}/dailyStats/{date}`.
  Future<void> updateDailyClaimStatus({
    required String date,
    required bool claimed,
    required int totalPoints, // The new total points after claiming the bonus
  }) async {
    final docRef = await _getDailyStatsDocRef(date); // Use the consistent path helper

    try {
      await docRef.set({
        'claimedDailyBonus': claimed,
        'totalPoints': totalPoints, // Update total points in daily record as well
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Daily bonus claim status updated for $date: $claimed.');
    } catch (e, stack) {
      debugPrint('❌ updateDailyClaimStatus failed: $e');
      debugPrint('Stack Trace: $stack');
      rethrow;
    }
  }

  /// Retrieves daily stats for a specific date.
  /// Data is retrieved from the consistent path: `users/{deviceId}/dailyStats/{date}`.
  Future<Map<String, dynamic>?> getDailyStatsOnce(String date) async {
    try {
      final docRef = await _getDailyStatsDocRef(date); // Use the consistent path helper
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        // Explicitly cast the data to Map<String, dynamic>
        return docSnapshot.data() as Map<String, dynamic>?;
      }
      return null; // Document does not exist
    } catch (e) {
      debugPrint('Error getting daily stats: $e');
      return null; // Return null on error
    }
  }

  // --- Redeeming Points (Spending Accumulated Points) ---

  /// Handles the redemption (spending) of accumulated points.
  /// This method decrements points from the main user profile document (`users/{deviceId}`)
  /// and optionally logs the redemption amount in the daily stats document.
  Future<bool> redeemDailyPoints({
    required String date, // Date for logging the daily redemption amount
    required int pointsToRedeem,
    required int currentTotalPoints, // The total points after local deduction
  }) async {
    final deviceId = await getDeviceId();
    // Reference to the main user profile document where overall total points are stored.
    // This is distinct from dailyStats and holds the grand total.
    final userProfileRef = _firestore.collection('users').doc(deviceId);

    return await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userProfileRef);

      if (!userSnapshot.exists) {
        debugPrint('User profile document does not exist for redemption. Cannot redeem points.');
        // You might want to create the user profile document here if it's expected to exist.
        return false;
      }

      // Safely get the current total points from the database.
      int currentDbTotalPoints = userSnapshot.data()?['totalPoints'] as int? ?? 0;

      if (currentDbTotalPoints < pointsToRedeem) {
        debugPrint('Insufficient points in DB for redemption. User has $currentDbTotalPoints, needs $pointsToRedeem.');
        return false;
      }

      // Decrement points in the user's main profile document.
      transaction.update(userProfileRef, {
        'totalPoints': FieldValue.increment(-pointsToRedeem),
        'lastRedeemedAt': FieldValue.serverTimestamp(), // Timestamp of this redemption
      });

      // Optionally, log the redeemed amount for the specific day in dailyStats.
      // This is separate from the 'claimedDailyBonus'.
      final dailyStatsDocRef = await _getDailyStatsDocRef(date); // Use the consistent path helper
      transaction.set(dailyStatsDocRef, {
        'pointsRedeemedToday': FieldValue.increment(pointsToRedeem), // Track amount redeemed today
        'lastRedeemedTimestamp': FieldValue.serverTimestamp(), // Timestamp of this specific redemption
      }, SetOptions(merge: true));

      return true; // Transaction successful
    }).catchError((error, stackTrace) {
      debugPrint('❌ Redemption transaction failed: $error');
      debugPrint('Stack Trace: $stackTrace');
      return false; // Transaction failed
    });
  }

  // --- Data Retrieval for Charts ---

  /// Retrieves weekly step data for the current device.
  /// Aggregates steps by weekday. Requires 'timestamp' field in dailyStats documents.
  Future<Map<String, int>> getWeeklyStepData() async {
    final deviceId = await getDeviceId();
    final now = DateTime.now().toLocal();
    // Calculate the start of the day 6 days ago (for a 7-day period including today)
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    final querySnapshot = await _firestore
        .collection('users') // Consistent parent collection
        .doc(deviceId)
        .collection('dailyStats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp') // Order by timestamp for correct chronological retrieval
        .get();

    final stepData = <String, int>{}; // Map to store aggregated steps by weekday label

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?; // Use null-aware access for data
      // Safely cast 'steps' to num then to int, defaulting to 0 if null or invalid.
      final steps = (data['steps'] as num?)?.toInt() ?? 0; // Use null-aware access for data

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal();
        final label = _getWeekdayLabel(date.weekday);
        stepData[label] = (stepData[label] ?? 0) + steps; // Aggregate steps for the same weekday
      }
    }

    // Initialize all 7 days of the week in correct order for display,
    // ensuring days with no data show 0 steps.
    final Map<String, int> orderedStepData = {};
    for (int i = 0; i < 7; i++) {
      // Calculate each day from 'sevenDaysAgo' up to 'today'
      final dateForDay = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day)
          .add(Duration(days: i));
      final label = _getWeekdayLabel(dateForDay.weekday);
      orderedStepData[label] = stepData[label] ?? 0; // Use aggregated data or 0
    }

    return orderedStepData;
  }

  /// Helper to convert a weekday integer (1=Monday, 7=Sunday) to a short label.
  String _getWeekdayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1]; // Adjust for 0-based list index
  }

  /// Retrieves monthly step data aggregated by week for the current device.
  /// Requires 'timestamp' field in dailyStats documents.
  Future<Map<String, int>> getMonthlyStepData() async {
    final deviceId = await getDeviceId();
    final now = DateTime.now().toLocal();
    // Calculate the start of the day 29 days ago (for a 30-day period including today)
    final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));

    final querySnapshot = await _firestore
        .collection('users') // Consistent parent collection
        .doc(deviceId)
        .collection('dailyStats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp') // Order by timestamp for correct chronological retrieval
        .get();

    final Map<String, int> weekData = {
      'Week 1': 0, // Represents days 0-6 from thirtyDaysAgo
      'Week 2': 0, // Represents days 7-13
      'Week 3': 0, // Represents days 14-20
      'Week 4': 0, // Represents days 21-27
      'Week 5': 0, // Represents days 28-29 (up to 30 days total)
    };

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?; // Use null-aware access for data
      final steps = (data['steps'] as num?)?.toInt() ?? 0; // Use null-aware access for data

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal();
        // Calculate the number of days from `thirtyDaysAgo` to the current document's date.
        // This ensures Week 1 correctly refers to the first week of the 30-day period.
        final int daysIntoPeriod = date.difference(thirtyDaysAgo).inDays;

        // Determine which 7-day bucket the date falls into (1-indexed week number)
        final int weekNumber = (daysIntoPeriod ~/ 7) + 1;

        if (weekNumber >= 1 && weekNumber <= 5) { // Ensure the week number is within our defined range
          final label = 'Week $weekNumber';
          weekData[label] = (weekData[label] ?? 0) + steps; // Aggregate steps for the corresponding week
        }
      }
    }
    return weekData;
  }

  // --- Deletion ---

  /// Deletes all dailyStats documents for the current device.
  /// Targets the consistent path: `users/{deviceId}/dailyStats` subcollection.
  /// Uses a batch write for efficient deletion of multiple documents.
  Future<void> deleteAllDailyStats() async {
    try {
      final deviceId = await getDeviceId();
      final collectionRef = _firestore
          .collection('users') // Consistent parent collection
          .doc(deviceId)
          .collection('dailyStats');

      final snapshot = await collectionRef.get();
      final batch = _firestore.batch(); // Create a batch for deletions
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference); // Add each document's deletion to the batch
      }
      await batch.commit(); // Commit all deletions at once
      debugPrint('🗑️ DatabaseService: All dailyStats documents deleted for device: $deviceId');
    } catch (e, stackTrace) {
      debugPrint('❌ DatabaseService: Failed to delete dailyStats: $e');
      debugPrint('Stack Trace: $stackTrace');
    }
  }
}