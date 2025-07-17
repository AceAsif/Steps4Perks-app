import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets a unique identifier for the device to use as a pseudo-user ID.
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // 'id' is guaranteed non-null in modern versions
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown-ios';
    } else {
      return 'unknown-platform';
    }
  }

  /// Saves the total points for the device in the 'userProfiles' collection.
  Future<void> saveTotalPoints(int totalPoints) async {
    try {
      final deviceId = await getDeviceId();
      await _firestore.collection('userProfiles').doc(deviceId).set({
        'totalPoints': totalPoints,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving total points: $e');
    }
  }

  /// Saves daily step stats for the device.
  Future<void> saveDailyStats({
    required String date,
    required int steps,
    required int totalPoints,
  }) async {
    try {
      final deviceId = await getDeviceId();

      debugPrint('💾 Saving daily stats for $date');
      debugPrint('🆔 Device ID: $deviceId');
      debugPrint('👣 Steps: $steps | 🪙 Points: $totalPoints');

      final docRef = _firestore
          .collection('stepStats')
          .doc(deviceId)
          .collection('dailyStats')
          .doc(date);

      await docRef.set({
        'steps': steps,
        'totalPoints': totalPoints,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Successfully saved daily stats!');
    } catch (e) {
      debugPrint('❌ Error saving daily stats: $e');
    }
  }


  /// Retrieves a stream of total points for the device.
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

  /// Retrieves a stream of daily stats for a specific date.
  Stream<Map<String, dynamic>?> getDailyStatsStream(String date) async* {
    final deviceId = await getDeviceId();
    final docRef = _firestore
        .collection('stepStats')
        .doc(deviceId)
        .collection('dailyStats')
        .doc(date);
    yield* docRef.snapshots().map((doc) => doc.data());
  }

  /// Get a stream of daily stats for a specific date (e.g., '2025-07-16')
  Stream<Map<String, dynamic>?> getDailyStats(String date) {
    final docRef = _firestore.collection('daily_stats').doc(date);

    return docRef.snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      } else {
        return null;
      }
    });
  }

  /// (Optional) Add this method if missing
  Future<void> updateDailyStats({
    required String date,
    required int steps,
    required int pointsEarnedToday,
    required int totalPointsAccumulated,
  }) async {
    final docRef = _firestore.collection('daily_stats').doc(date);
    await docRef.set({
      'steps': steps,
      'pointsEarnedToday': pointsEarnedToday,
      'totalPointsAccumulated': totalPointsAccumulated,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
