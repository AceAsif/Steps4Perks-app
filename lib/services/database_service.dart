import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedDeviceId;

  /// Get and cache the device ID once
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

  /// Save total points
  Future<void> saveTotalPoints(int totalPoints) async {
    try {
      final deviceId = await getDeviceId();

      await _firestore
          .collection('userProfiles')
          .doc(deviceId)
          .set({
            'totalPoints': totalPoints,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Total points saved: $totalPoints');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase error (saveTotalPoints): ${e.message}');
    } catch (e) {
      debugPrint('❌ Error saving total points: $e');
    }
  }

  /// Save daily stats including steps, points, streak
  Future<void> saveDailyStats({
    required String date,
    required int steps,
    required int totalPoints,
    required int streak,
  }) async {
    try {
      final deviceId = await getDeviceId();

      final docRef = _firestore
          .collection('stepStats')
          .doc(deviceId)
          .collection('dailyStats')
          .doc(date);

      await docRef
          .set({
            'steps': steps,
            'totalPoints': totalPoints,
            'streak': streak,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Successfully saved daily stats for $date');
    } on FirebaseException catch (e) {
      debugPrint('🔥 Firebase error (saveDailyStats): ${e.message}');
    } catch (e) {
      debugPrint('❌ Error saving daily stats: $e');
    }
  }

  /// Stream of total points
  Stream<int> getTotalPointsStream() async* {
    final deviceId = await getDeviceId();
    final docRef = _firestore.collection('userProfiles').doc(deviceId);
    yield* docRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data()?['totalPoints'] ?? 0;
      }
      return 0;
    });
  }

  /// Stream of daily stats
  Stream<Map<String, dynamic>?> getDailyStatsStream(String date) async* {
    final deviceId = await getDeviceId();
    final docRef = _firestore
        .collection('stepStats')
        .doc(deviceId)
        .collection('dailyStats')
        .doc(date);

    yield* docRef.snapshots().map((doc) => doc.data());
  }

  /// Generic daily stats stream from 'daily_stats' (optional)
  Stream<Map<String, dynamic>?> getDailyStats(String date) {
    final docRef = _firestore.collection('daily_stats').doc(date);
    return docRef.snapshots().map((snapshot) {
      if (snapshot.exists) return snapshot.data();
      return null;
    });
  }

  /// Optional: Update fallback `daily_stats` collection
  Future<void> updateDailyStats({
    required String date,
    required int steps,
    required int pointsEarnedToday,
    required int totalPointsAccumulated,
  }) async {
    try {
      final docRef = _firestore.collection('daily_stats').doc(date);
      await docRef
          .set({
            'steps': steps,
            'pointsEarnedToday': pointsEarnedToday,
            'totalPointsAccumulated': totalPointsAccumulated,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ Failed to update daily_stats for $date: $e');
    }
  }
}
