import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:intl/intl.dart';

// NEW IMPORTS FOR THE REWARD MODELS
import 'package:myapp/models/available_reward_item.dart';
import 'package:myapp/models/redeemed_reward_history_item.dart';

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

  /// Manually syncs local data to Firestore. This is useful for providing a sync button
  /// to the user for manual data saving and error recovery.
  Future<bool> manualSync() async {
    try {
      debugPrint('🔄 Starting manual sync...');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

      // Fetch the latest data from your local state/step tracker service.
      final localSteps = StepTracker.instance.getTodaySteps;
      final localDailyPoints = StepTracker.instance.getDailyPointsEarned;
      final localStreak = StepTracker.instance.getStreak;
      final hasClaimedBonus = StepTracker.instance.hasClaimedDailyBonus;

      // Use the existing save method to push this data to Firestore.
      await saveStatsAndPoints(
        date: today,
        steps: localSteps,
        dailyPointsEarned: localDailyPoints,
        streak: localStreak,
        claimedDailyBonus: hasClaimedBonus,
      );

      // Also update the main user profile with the latest streak and total points
      // from the StepTracker to ensure consistency.
      await setUserProfileStreak(localStreak);

      // Since totalPoints is managed by `claimDailyPoints` and `redeemDailyPoints`,
      // we don't need to update it here.

      debugPrint('✅ Manual sync successful!');
      return true;
    } catch (e) {
      debugPrint('❌ Manual sync failed: $e');
      return false;
    }
  }

  /// Saves or updates daily step statistics for a specific date.
  /// Data is stored under the consistent path: `users/{deviceId}/dailyStats/{date}`.
  /// Total points are now managed primarily in the main user profile document.
  Future<void> saveStatsAndPoints({
    required String date,
    required int steps,
    required int dailyPointsEarned,
    required int streak,
    // Removed totalPoints from here as it should be managed centrally
    bool claimedDailyBonus = false,
  }) async {
    final docRef = await _getDailyStatsDocRef(date); // Use the consistent path helper

    final batch = _firestore.batch(); // Use a batch for atomic updates

    batch.set(docRef, {
      'date': date,
      'steps': steps,
      'dailyPointsEarned': dailyPointsEarned,
      'streak': streak,
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

  /// Updates only the daily bonus claim status for a specific date.
  /// Data is updated under the consistent path: `users/{deviceId}/dailyStats/{date}`.
  /// Total points are now managed primarily in the main user profile document.
  Future<void> updateDailyClaimStatus({
    required String date,
    required bool claimed,
    // Removed totalPoints from here as it should be managed centrally
  }) async {
    final docRef = await _getDailyStatsDocRef(date); // Use the consistent path helper

    try {
      await docRef.set({
        'claimedDailyBonus': claimed,
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
    required int currentTotalPoints, // The total points after local deduction (for transaction check)
  }) async {
    final deviceId = await getDeviceId();
    // Reference to the main user profile document where overall total points are stored.
    final userProfileRef = _firestore.collection('users').doc(deviceId);

    return await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userProfileRef);

      // Safely get the current total points from the database.
      int currentDbTotalPoints = userSnapshot.data()?['totalPoints'] as int? ?? 0;

      if (currentDbTotalPoints < pointsToRedeem) {
        debugPrint('Insufficient points in DB for redemption. User has $currentDbTotalPoints, needs $pointsToRedeem.');
        return false;
      }

      // Decrement points in the user's main profile document.
      // Use .set with merge:true to create document if it doesn't exist, or merge if it does.
      transaction.set(userProfileRef, {
        'totalPoints': FieldValue.increment(-pointsToRedeem),
        'lastRedeemedAt': FieldValue.serverTimestamp(), // Timestamp of this redemption
      }, SetOptions(merge: true));

      // Optionally, log the redeemed amount for the specific day in dailyStats.
      final dailyStatsDocRef = await _getDailyStatsDocRef(date);
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

  // --- Rewards & Points Management ---

  // MODIFIED: addRedeemedReward to accept rewardName and pointsCost for history
  Future<void> addRedeemedReward({
    required String rewardType,
    required num value,
    required String status,
    String? giftCardCode,
    String? rewardName,
    int? pointsCost,
    String? imageUrl,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final rewardRef = _firestore
          .collection('users')
          .doc(deviceId)
          .collection('redeemed_rewards')
          .doc(); // auto ID

      final data = {
        'rewardType': rewardType,
        'value': value,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        if (giftCardCode != null) 'giftCardCode': giftCardCode,
        if (rewardName != null) 'rewardName': rewardName,
        if (pointsCost != null) 'pointsCost': pointsCost,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      await rewardRef.set(data);

      debugPrint('🎁 addRedeemedReward: Added $rewardType reward with value $value');
    } catch (e, stackTrace) {
      debugPrint('❌ addRedeemedReward error: $e');
      debugPrint('Stack Trace: $stackTrace');
    }
  }

  Future<void> claimDailyPoints() async {
    final deviceId = await getDeviceId();
    final userRef = _firestore.collection('users').doc(deviceId);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final dailyStatsRef = userRef.collection('dailyStats').doc(today);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      // Get existing total points, default to 0 if document/field doesn't exist
      final int currentTotalPoints = (userSnapshot.data()?['totalPoints'] as int? ?? 0);

      // 1. update user profile totalPoints. Use .set with merge:true to create if not exists.
      transaction.set(userRef, {
        'totalPoints': currentTotalPoints + StepTracker.maxDailyPoints,
        'lastClaimedAt': FieldValue.serverTimestamp(), // Track when points were last claimed
      }, SetOptions(merge: true));

      // 2. update today’s dailyStats document
      transaction.set(dailyStatsRef, {
        'claimedDailyBonus': true,
        'dailyPointsEarned': StepTracker.maxDailyPoints,
        'date': today,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // MODIFIED: getTotalPointsFromUserProfile to fetch from the main user document
  Future<int> getTotalPointsFromUserProfile() async {
    final deviceId = await getDeviceId();
    final userProfileRef = _firestore.collection('users').doc(deviceId);
    try {
      final userSnapshot = await userProfileRef.get();
      if (userSnapshot.exists) {
        return userSnapshot.data()?['totalPoints'] as int? ?? 0;
      } else {
        return 0; // User profile document doesn't exist
      }
    } catch (e) {
      debugPrint('Error getting total points from user profile: $e');
      return 0; // Return 0 on error
    }
  }

  // Set user's current streak on the main user profile doc
  Future<void> setUserProfileStreak(int streak) async {
    final deviceId = await getDeviceId();
    final userRef = _firestore.collection('users').doc(deviceId);
    try {
      await userRef.set({
        'currentStreak': streak,
        'streakUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ setUserProfileStreak → $streak');
    } catch (e, stack) {
      debugPrint('❌ setUserProfileStreak failed: $e');
      debugPrint('Stack Trace: $stack');
      rethrow;
    }
  }

  // Get user's current streak from the main user profile doc
  Future<int> getUserProfileStreak() async {
    final deviceId = await getDeviceId();
    final userRef = _firestore.collection('users').doc(deviceId);
    try {
      final snap = await userRef.get();
      return snap.data()?['currentStreak'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ getUserProfileStreak error: $e');
      return 0;
    }
  }

  // MODIFIED: fetchRedeemedRewards to return List<RedeemedRewardHistoryItem>
  Future<List<RedeemedRewardHistoryItem>> fetchRedeemedRewards(String deviceId) async {
    try {
      final rewardRef = _firestore
          .collection('users')
          .doc(deviceId)
          .collection('redeemed_rewards');

      final querySnapshot = await rewardRef.get();
      final rewardList = querySnapshot.docs.map((doc) {
        return RedeemedRewardHistoryItem.fromFirestore(doc.id, doc.data());
      }).toList();

      return rewardList;
    } catch (e) {
      debugPrint('Error fetching redeemed rewards: $e'); // <--- CHANGE FROM print TO debugPrint
      return [];
    }
  }

  // MODIFIED: fetchAvailableRewards to query rewards_catalogue and return List<AvailableRewardItem>
  Future<List<AvailableRewardItem>> fetchAvailableRewards() async {
    try {
      final snapshot = await _firestore
          .collection('rewards_catalogue')
          .where('isActive', isEqualTo: true)
          .orderBy('rewardName') // Order by rewardName
          .get();

      return snapshot.docs
          .map((doc) => AvailableRewardItem.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching available rewards: $e');
      return [];
    }
  }
}