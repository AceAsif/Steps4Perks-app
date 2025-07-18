import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedDeviceId;

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
        _cachedDeviceId = 'unknown-platform';
      }
    } catch (e) {
      debugPrint('❌ Failed to retrieve device ID: $e');
      _cachedDeviceId = 'error-device';
    }

    return _cachedDeviceId!;
  }

  Future<void> saveTotalPoints(int totalPoints) async {
    try {
      final deviceId = await getDeviceId();
      await _firestore.collection('userProfiles').doc(deviceId).set({
        'totalPoints': totalPoints,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      debugPrint('✅ Total points saved: $totalPoints');
    } catch (e) {
      debugPrint('❌ Error saving total points: $e');
    }
  }

  Future<void> saveDailyStats({
    required String date,
    required int steps,
    required int totalPoints,
    required int streak,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final docRef = _firestore.collection('stepStats').doc(deviceId).collection('dailyStats').doc(date);
      await docRef.set({
        'steps': steps,
        'totalPoints': totalPoints,
        'streak': streak,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      debugPrint('✅ Successfully saved daily stats for $date');
    } catch (e) {
      debugPrint('❌ Error saving daily stats: $e');
    }
  }

  Stream<int> getTotalPointsStream() async* {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('userProfiles').doc(deviceId);
    yield* docRef.snapshots().map((snapshot) => snapshot.data()?['totalPoints'] ?? 0);
  }

  Stream<Map<String, dynamic>?> getDailyStatsStream(String date) async* {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('stepStats').doc(deviceId).collection('dailyStats').doc(date);
    yield* docRef.snapshots().map((doc) => doc.data());
  }

  Stream<Map<String, dynamic>?> getDailyStats(String date) {
    final docRef = _firestore.collection('daily_stats').doc(date);
    return docRef.snapshots().map((snapshot) => snapshot.exists ? snapshot.data() : null);
  }

  Future<void> updateDailyStats({
    required String date,
    required int steps,
    required int pointsEarnedToday,
    required int totalPointsAccumulated,
  }) async {
    try {
      final docRef = _firestore.collection('daily_stats').doc(date);
      await docRef.set({
        'steps': steps,
        'pointsEarnedToday': pointsEarnedToday,
        'totalPointsAccumulated': totalPointsAccumulated,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Failed to update daily_stats for $date: $e');
    }
  }

  Future<bool> redeemDailyPoints({
    required String date,
    int pointsToRedeem = 100,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final dailyDocRef = _firestore.collection('stepStats').doc(deviceId).collection('dailyStats').doc(date);
      final profileRef = _firestore.collection('userProfiles').doc(deviceId);
      final dailySnapshot = await dailyDocRef.get();

      if (dailySnapshot.exists && dailySnapshot.data()?['redeemed'] == true) {
        debugPrint('🟡 Points already redeemed for $date');
        return false;
      }

      await _firestore.runTransaction((transaction) async {
        final profileSnapshot = await transaction.get(profileRef);
        final currentTotal = profileSnapshot.data()?['totalPoints'] ?? 0;
        final newTotal = currentTotal + pointsToRedeem;

        transaction.update(profileRef, {
          'totalPoints': newTotal,
          'timestamp': FieldValue.serverTimestamp(),
        });

        transaction.set(dailyDocRef, {
          'redeemed': true,
          'pointsRedeemed': pointsToRedeem,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      debugPrint('✅ Successfully redeemed $pointsToRedeem points for $date');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to redeem points for $date: $e');
      return false;
    }
  }

  Future<Map<String, int>> getWeeklyStepData() async {
    final deviceId = await getDeviceId();
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 6));

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
      final steps = data['steps'] ?? 0;

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal(); // ensure local comparison
        final label = _getWeekdayLabel(date.weekday);
        stepData[label] = steps;
      }
    }

    for (int i = 0; i < 7; i++) {
      final date = sevenDaysAgo.add(Duration(days: i));
      final label = _getWeekdayLabel(date.weekday);
      stepData.putIfAbsent(label, () => 0);
    }

    return stepData;
  }

  String _getWeekdayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
  }
}
