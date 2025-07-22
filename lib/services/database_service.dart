import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedDeviceId;

  // --- Device ID Management ---
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceId = androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      } else {
        _cachedDeviceId = 'unknown-platform-id';
        debugPrint('⚠️ Running on an unexpected platform.');
      }
    } catch (e) {
      debugPrint('❌ Failed to retrieve device ID: $e');
      _cachedDeviceId = 'error-device-retrieval';
    }

    if (_cachedDeviceId == null || _cachedDeviceId!.isEmpty) {
      _cachedDeviceId = 'default-fallback-id';
    }
    return _cachedDeviceId!;
  }

  // --- Batching Method ---
  Future<void> saveStatsAndPoints({
    required String date,
    required int steps,
    required int dailyPointsEarned, // Added this
    required int streak,
    required int totalPoints,     // Added this
  }) async {
    try {
      final deviceId = await getDeviceId();
      final batch = _firestore.batch();

      final statsRef = _firestore
          .collection('stepStats')
          .doc(deviceId)
          .collection('dailyStats')
          .doc(date);

      final pointsRef = _firestore
          .collection('userProfiles')
          .doc(deviceId);

      batch.set(statsRef, {
        'steps': steps,
        'dailyPointsEarned': dailyPointsEarned, // Use the passed value
        'streak': streak,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(pointsRef, {
        'totalPoints': totalPoints, // Use the passed value
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('✅ saveStatsAndPoints: Batching complete for $date.');
    } catch (e, stackTrace) {
      debugPrint('❌ saveStatsAndPoints error: $e');
      debugPrint('Stack Trace: $stackTrace');
    }
  }

  // --- Missing Methods ---
  Future<Map<String, dynamic>?> getDailyStatsOnce(String date) async {
    try {
      final deviceId = await getDeviceId();
      final doc = await _firestore
          .collection('stepStats')
          .doc(deviceId)
          .collection('dailyStats')
          .doc(date)
          .get();

      return doc.exists ? doc.data() : null;
    } catch (e, stackTrace) {
      debugPrint('❌ getDailyStatsOnce error: $e');
      debugPrint('Stack Trace: $stackTrace');
      return null;
    }
  }

  Future<bool> updateDailyStatsRedeemedStatus({
    required String date,
    required bool redeemed,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final docRef = _firestore
          .collection('stepStats')
          .doc(deviceId)
          .collection('dailyStats')
          .doc(date);

      await docRef.set({
        'redeemed': redeemed,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ updateDailyStatsRedeemedStatus: $date → $redeemed');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ updateDailyStatsRedeemedStatus failed: $e');
      debugPrint('Stack Trace: $stackTrace');
      return false;
    }
  }

  // --- Redeeming Points ---
  Future<bool> redeemDailyPoints({
    required String date,
    required int pointsToRedeem, // Pass the actual points to be redeemed
    required int currentTotalPoints, // Pass the current total points from StepTracker
  }) async {
    try {
      final deviceId = await getDeviceId();
      final dailyDocRef = _firestore.collection('stepStats').doc(deviceId).collection('dailyStats').doc(date);
      final profileRef = _firestore.collection('userProfiles').doc(deviceId);

      // Check if already redeemed - crucial to prevent double redemption
      final dailySnapshot = await dailyDocRef.get();
      if (dailySnapshot.exists && (dailySnapshot.data()?['redeemed'] == true || dailySnapshot.data()?['pointsRedeemed'] != null)) {
        debugPrint('🟡 DatabaseService: Points already redeemed for $date or redemption recorded.');
        return false;
      }

      // Use a transaction to update both documents atomically
      await _firestore.runTransaction((transaction) async {
        // 1. Update total points in userProfiles
        // We are directly setting the value passed from StepTracker,
        // because StepTracker already subtracted points locally.
        transaction.set(profileRef, {
          'totalPoints': currentTotalPoints, // Set the updated total points from StepTracker
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Mark daily stats as redeemed
        transaction.set(dailyDocRef, {
          'redeemed': true,
          'pointsRedeemed': pointsToRedeem, // Record how many points were redeemed from this day's earnings
          'redeemedAt': FieldValue.serverTimestamp(), // New field for clarity
        }, SetOptions(merge: true));
      }).timeout(const Duration(seconds: 10));

      debugPrint('✅ DatabaseService: Successfully redeemed $pointsToRedeem points for $date');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ DatabaseService: Failed to redeem points for $date: $e');
      debugPrint('Stack Trace: $stackTrace');
      return false;
    }
  }

  // --- Data Retrieval for Charts ---
  Future<Map<String, int>> getWeeklyStepData() async {
    final deviceId = await getDeviceId();
    final now = DateTime.now().toLocal(); // Ensure local time for consistent day calculation
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)); // Start of the day 6 days ago

    final querySnapshot = await _firestore
        .collection('stepStats')
        .doc(deviceId)
        .collection('dailyStats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp')
        .get();

    final stepData = <String, int>{};

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      final steps = (data['steps'] as num?)?.toInt() ?? 0; // Cast to num then to Int

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal();
        final label = _getWeekdayLabel(date.weekday);
        stepData[label] = (stepData[label] ?? 0) + steps; // Aggregate steps for the same weekday
      }
    }

    // Initialize all 7 days of the week, ensuring correct order for display
    final Map<String, int> orderedStepData = {};
    for (int i = 0; i < 7; i++) {
      final dateForDay = sevenDaysAgo.add(Duration(days: i));
      final label = _getWeekdayLabel(dateForDay.weekday);
      orderedStepData[label] = stepData[label] ?? 0; // Use aggregated data or 0
    }

    return orderedStepData;
  }


  String _getWeekdayLabel(int weekday) {
    // Weekday constants from DateTime class (1 = Monday, 7 = Sunday)
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1]; // Adjust for 0-based index
  }

  Future<Map<String, int>> getMonthlyStepData() async {
    final deviceId = await getDeviceId();
    final now = DateTime.now().toLocal();
    final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)); // Start of the day 29 days ago

    final querySnapshot = await _firestore
        .collection('stepStats')
        .doc(deviceId)
        .collection('dailyStats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('timestamp')
        .get();

    final Map<String, int> weekData = {
      'Week 1': 0,
      'Week 2': 0,
      'Week 3': 0,
      'Week 4': 0,
      'Week 5': 0,
    };

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      final steps = (data['steps'] as num?)?.toInt() ?? 0;

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal();
        // Calculate days ago relative to 'now'
        final int daysDifference = now.difference(date).inDays;
        // Determine which 7-day period the date falls into, starting from 30 days ago
        final int weekNumber = (daysDifference ~/ 7) + 1;

        if (weekNumber <= 5 && weekNumber >= 1) { // Ensure it falls within our 5-week range
          final label = 'Week $weekNumber';
          weekData[label] = ((weekData[label] ?? 0) + steps).toInt();
        }
      }
    }
    return weekData;
  }

  // --- Deletion ---
  Future<void> deleteAllDailyStats() async {
    try {
      final deviceId = await getDeviceId();
      final collectionRef = _firestore
          .collection('stepStats')
          .doc(deviceId)
          .collection('dailyStats');

      final snapshot = await collectionRef.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('🗑️ DatabaseService: All dailyStats documents deleted for device: $deviceId');
    } catch (e, stackTrace) {
      debugPrint('❌ DatabaseService: Failed to delete dailyStats: $e');
      debugPrint('Stack Trace: $stackTrace');
    }
  }
}