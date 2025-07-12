import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get the current user's UID
import 'package:flutter/material.dart'; // For debugPrint
import 'package:intl/intl.dart'; // For DateFormat

/// A service class to handle all interactions with Firebase Firestore.
/// It uses the Canvas-provided APP_ID and current user's UID for data paths,
/// adhering to Firebase security rules for private user data.
class DatabaseService {
  // Singleton pattern for easy access throughout the app
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MANDATORY for Canvas: Get the current app ID from the environment.
  // This is used to construct the correct Firestore collection paths.
  // The 'APP_ID' environment variable is provided by the Canvas runtime.
  final String _appId = const String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

  // Helper to get the current authenticated user's ID.
  // This will be null if no user is signed in.
  String? get currentUserId => _auth.currentUser?.uid;

  // --- Common Firestore Collection Paths ---
  // FIX: _userDoc returns a DocumentReference to the user's specific document.
  // This is the correct pattern to then access sub-collections like 'profiles', 'daily_stats', etc.
  DocumentReference _userDoc(String userId) {
    return _db.collection('artifacts').doc(_appId).collection('users').doc(userId);
  }

  // --- User Profile & Total Points ---
  /// Saves or updates a user's profile information and total points in Firestore.
  /// Data is stored under `/artifacts/{appId}/users/{userId}/profiles/{userId}`.
  Future<void> saveUserProfile({
    required String name,
    required String email,
    int? totalPoints, // Optional: Update total points as part of profile
    int? currentStreak, // Optional: Update streak as part of profile
    String? lastGoalAchievedDate, // Optional: Update last goal date as part of profile
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for saving profile.');
      return;
    }
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(), // Timestamp of last update
      };
      if (totalPoints != null) data['totalPoints'] = totalPoints;
      if (currentStreak != null) data['currentStreak'] = currentStreak;
      if (lastGoalAchievedDate != null) data['lastGoalAchievedDate'] = lastGoalAchievedDate;

      // FIX: Call .collection('profiles').doc(userId) on the DocumentReference returned by _userDoc
      await _userDoc(userId).collection('profiles').doc(userId).set(
        data,
        SetOptions(merge: true), // Use merge: true to update fields without overwriting the whole document
      );
      debugPrint('DatabaseService: User profile saved/updated for $userId');
    } catch (e) {
      debugPrint('DatabaseService Error saving profile: $e');
    }
  }

  /// Retrieves a user's profile information as a stream.
  /// Listens for real-time updates to the profile document.
  Stream<Map<String, dynamic>?> getUserProfile() {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for getting profile.');
      return Stream.value(null); // Return an empty stream if no user
    }
    // FIX: Call .collection('profiles').doc(userId) on the DocumentReference returned by _userDoc
    return _userDoc(userId)
        .collection('profiles')
        .doc(userId)
        .snapshots() // Listen for real-time changes
        .map((snapshot) => snapshot.data()); // Map snapshot to data map
  }

  // --- Daily Stats (Steps & Points Earned Today) ---
  /// Updates a user's daily step count and points earned for a specific date.
  /// Data is stored under `/artifacts/{appId}/users/{userId}/daily_stats/{date}`.
  Future<void> updateDailyStats({
    required int steps,
    required int pointsEarnedToday, // Points earned on this specific day
    required int totalPointsAccumulated, // Total points across all days (for snapshot)
    required String date, // Format: 'YYYY-MM-DD'
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for updating daily stats.');
      return;
    }
    try {
      // FIX: Call .collection('daily_stats').doc(date) on the DocumentReference returned by _userDoc
      await _userDoc(userId).collection('daily_stats').doc(date).set({
        'steps': steps,
        'pointsEarnedToday': pointsEarnedToday,
        'totalPointsAccumulated': totalPointsAccumulated, // Snapshot of total points at this daily update
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Use merge to update existing fields or create if not exists
      debugPrint('DatabaseService: Daily stats updated for $userId on $date: $steps steps, $pointsEarnedToday points');
    } catch (e) {
      debugPrint('DatabaseService Error updating daily stats: $e');
    }
  }

  /// Retrieves a stream of a user's daily stats for a specific date.
  Stream<Map<String, dynamic>?> getDailyStats(String date) {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for getting daily stats.');
      return Stream.value(null);
    }
    // FIX: Call .collection('daily_stats').doc(date) on the DocumentReference returned by _userDoc
    return _userDoc(userId)
        .collection('daily_stats')
        .doc(date)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  /// Retrieves a stream of daily step data for a given date range (e.g., for charts).
  Stream<List<Map<String, dynamic>>> getDailyStatsRange(DateTime startDate, DateTime endDate) {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for getting daily stats range.');
      return Stream.value([]);
    }
    // FIX: Call .collection('daily_stats') on the DocumentReference returned by _userDoc
    return _userDoc(userId)
        .collection('daily_stats')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate))
        .where(FieldPath.documentId, isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endDate))
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()..['date'] = doc.id).toList()); // Add doc ID as 'date'
  }

  // --- Redeemed Rewards ---
  /// Adds a record of a redeemed reward to Firestore.
  /// Stored under `/artifacts/{appId}/users/{userId}/redeemed_rewards`.
  Future<void> addRedeemedReward({
    required String rewardType,
    required double value,
    required String status, // e.g., 'pending', 'fulfilled'
    String? giftCardCode, // Optional: for actual gift card code
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for adding reward.');
      return;
    }
    try {
      // FIX: Call .collection('redeemed_rewards') on the DocumentReference returned by _userDoc
      await _userDoc(userId).collection('redeemed_rewards').add({
        'rewardType': rewardType,
        'value': value,
        'status': status,
        'giftCardCode': giftCardCode,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('DatabaseService: Redeemed reward added for $userId: $rewardType');
    } catch (e) {
      debugPrint('DatabaseService Error adding redeemed reward: $e');
    }
  }

  /// Retrieves a stream of all redeemed rewards for the current user.
  Stream<List<Map<String, dynamic>>> getRedeemedRewards() {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('DatabaseService Error: User not authenticated for getting rewards.');
      return Stream.value([]);
    }
    // FIX: Call .collection('redeemed_rewards') on the DocumentReference returned by _userDoc
    return _userDoc(userId)
        .collection('redeemed_rewards')
        .orderBy('timestamp', descending: true) // Order by timestamp
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
