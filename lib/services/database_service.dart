import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:intl/intl.dart';
import 'package:myapp/models/available_reward_item.dart';
import 'package:myapp/models/redeemed_reward_history_item.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- User ID Management ---
  String? getUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // --- Helper for Consistent Document Paths ---
  DocumentReference? _getDailyStatsDocRef(String date) {
    final userUid = getUserId();
    if (userUid == null) {
      debugPrint('❌ _getDailyStatsDocRef: User not authenticated.');
      return null;
    }
    return _firestore
        .collection('users')
        .doc(userUid)
        .collection('dailyStats')
        .doc(date);
  }

  // --- 🟢 NEW: Profile Image Management ---

  /// Save profile picture index to Firestore
  Future<void> saveProfileImageIndex(int index) async {
    final userUid = getUserId();
    if (userUid == null) {
      debugPrint('❌ saveProfileImageIndex: No user logged in');
      return;
    }

    try {
      await _firestore.collection('users').doc(userUid).set({
        'profileImageIndex': index,
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Saved profile image index to Firestore: $index');
    } catch (e, stack) {
      debugPrint('❌ Error saving profile image to Firestore: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  /// Load profile picture index from Firestore
  Future<int?> loadProfileImageIndex() async {
    final userUid = getUserId();
    if (userUid == null) {
      debugPrint('❌ loadProfileImageIndex: No user logged in');
      return null;
    }

    try {
      final doc = await _firestore.collection('users').doc(userUid).get();

      if (!doc.exists) {
        debugPrint('⚠️ User document does not exist yet');
        return null;
      }

      final data = doc.data();
      final index = data?['profileImageIndex'] as int?;

      if (index != null) {
        debugPrint('📸 Loaded profile image index from Firestore: $index');
      } else {
        debugPrint('⚠️ No profile image index found in Firestore (will use default)');
      }

      return index;
    } catch (e, stack) {
      debugPrint('❌ Error loading profile image from Firestore: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  // --- Core Data Operations ---

  /// Manual sync - accepts StepTracker instance as parameter
  Future<bool> manualSync(StepTracker stepTracker) async {
    final userUid = getUserId();
    if (userUid == null) {
      debugPrint('❌ manualSync: User not authenticated. Cannot sync.');
      return false;
    }

    try {
      debugPrint('🔄 Starting manual sync...');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());

      final localSteps = stepTracker.getTodaySteps;
      final localDailyPoints = stepTracker.getDailyPointsEarned;
      final localStreak = stepTracker.getStreak;
      final hasClaimedBonus = stepTracker.hasClaimedDailyBonus;

      await saveStatsAndPoints(
        date: today,
        steps: localSteps,
        dailyPointsEarned: localDailyPoints,
        streak: localStreak,
        claimedDailyBonus: hasClaimedBonus,
      );

      await setUserProfileStreak(localStreak);
      debugPrint('✅ Manual sync successful!');
      return true;
    } catch (e) {
      debugPrint('❌ Manual sync failed: $e');
      return false;
    }
  }

  /// Saves or updates daily step statistics for a specific date
  Future<void> saveStatsAndPoints({
    required String date,
    required int steps,
    required int dailyPointsEarned,
    required int streak,
    bool claimedDailyBonus = false,
  }) async {
    final docRef = _getDailyStatsDocRef(date);
    if (docRef == null) return;

    final batch = _firestore.batch();
    batch.set(docRef, {
      'date': date,
      'steps': steps,
      'dailyPointsEarned': dailyPointsEarned,
      'streak': streak,
      'claimedDailyBonus': claimedDailyBonus,
      'lastUpdated': FieldValue.serverTimestamp(),
      'timestamp': Timestamp.fromDate(DateFormat('yyyy-MM-dd').parse(date)),
    }, SetOptions(merge: true));

    try {
      await batch.commit();
      debugPrint('✅ saveStatsAndPoints: Batching complete for $date.');
    } catch (e, stack) {
      debugPrint('❌ saveStatsAndPoints failed: $e');
      debugPrint('Stack Trace: $stack');
      rethrow;
    }
  }

  /// Updates only the daily bonus claim status for a specific date
  Future<void> updateDailyClaimStatus({
    required String date,
    required bool claimed,
  }) async {
    final docRef = _getDailyStatsDocRef(date);
    if (docRef == null) return;

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

  /// Retrieves daily stats for a specific date
  Future<Map<String, dynamic>?> getDailyStatsOnce(String date) async {
    try {
      final docRef = _getDailyStatsDocRef(date);
      if (docRef == null) return null;

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        return docSnapshot.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting daily stats: $e');
      return null;
    }
  }

  // --- Redeeming Points (Spending Accumulated Points) ---
  Future<bool> redeemDailyPoints({
    required String date,
    required int pointsToRedeem,
    required int currentTotalPoints,
  }) async {
    final userUid = getUserId();
    if (userUid == null) {
      debugPrint('❌ redeemDailyPoints: User not authenticated.');
      return false;
    }

    final userProfileRef = _firestore.collection('users').doc(userUid);
    return await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userProfileRef);
      int currentDbTotalPoints = userSnapshot.data()?['totalPoints'] as int? ?? 0;

      if (currentDbTotalPoints < pointsToRedeem) {
        debugPrint('Insufficient points in DB for redemption. User has $currentDbTotalPoints, needs $pointsToRedeem.');
        return false;
      }

      transaction.set(userProfileRef, {
        'totalPoints': FieldValue.increment(-pointsToRedeem),
        'lastRedeemedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final dailyStatsDocRef = _getDailyStatsDocRef(date);
      if (dailyStatsDocRef != null) {
        transaction.set(dailyStatsDocRef, {
          'pointsRedeemedToday': FieldValue.increment(pointsToRedeem),
          'lastRedeemedTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return true;
    }).catchError((error, stackTrace) {
      debugPrint('❌ Redemption transaction failed: $error');
      debugPrint('Stack Trace: $stackTrace');
      return false;
    });
  }

  // --- Data Retrieval for Charts ---
  Future<Map<String, int>> getWeeklyStepData() async {
    final userUid = getUserId();
    if (userUid == null) return {};

    final now = DateTime.now().toLocal();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));

    final querySnapshot = await _firestore
        .collection('users')
        .doc(userUid)
        .collection('dailyStats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp')
        .get();

    final stepData = <String, int>{};
    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      final steps = (data['steps'] as num?)?.toInt() ?? 0;

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal();
        final label = _getWeekdayLabel(date.weekday);
        stepData[label] = (stepData[label] ?? 0) + steps;
      }
    }

    final Map<String, int> orderedStepData = {};
    for (int i = 0; i < 7; i++) {
      final dateForDay = DateTime(sevenDaysAgo.year, sevenDaysAgo.month, sevenDaysAgo.day)
          .add(Duration(days: i));
      final label = _getWeekdayLabel(dateForDay.weekday);
      orderedStepData[label] = stepData[label] ?? 0;
    }

    return orderedStepData;
  }

  String _getWeekdayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Future<Map<String, int>> getMonthlyStepData() async {
    final userUid = getUserId();
    if (userUid == null) return {};

    final now = DateTime.now().toLocal();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfNextMonth = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);

    final querySnapshot = await _firestore
        .collection('users')
        .doc(userUid)
        .collection('dailyStats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('timestamp', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .orderBy('timestamp')
        .get();

    final Map<String, int> weekData = {
      'Week 1': 0, 'Week 2': 0, 'Week 3': 0, 'Week 4': 0, 'Week 5': 0,
    };

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = data['timestamp'] as Timestamp?;
      final steps = (data['steps'] as num?)?.toInt() ?? 0;

      if (timestamp != null) {
        final date = timestamp.toDate().toLocal();
        final int weekIndexZeroBased = ((date.day - 1) ~/ 7);
        final int weekNumber = (weekIndexZeroBased + 1).clamp(1, 5);
        final label = 'Week $weekNumber';
        weekData[label] = (weekData[label] ?? 0) + steps;
      }
    }

    return weekData;
  }

  // --- Deletion ---
  Future<void> deleteAllDailyStats() async {
    final userUid = getUserId();
    if (userUid == null) return;

    try {
      final collectionRef = _firestore
          .collection('users')
          .doc(userUid)
          .collection('dailyStats');

      final snapshot = await collectionRef.get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('🗑️ DatabaseService: All dailyStats documents deleted for user: $userUid');
    } catch (e, stackTrace) {
      debugPrint('❌ DatabaseService: Failed to delete dailyStats: $e');
      debugPrint('Stack Trace: $stackTrace');
    }
  }

  // --- Rewards & Points Management ---
  Future<void> addRedeemedReward({
    required String rewardType,
    required num value,
    required String status,
    String? giftCardCode,
    String? rewardName,
    int? pointsCost,
    String? imageUrl,
  }) async {
    final userUid = getUserId();
    if (userUid == null) return;

    try {
      final rewardRef = _firestore
          .collection('users')
          .doc(userUid)
          .collection('redeemed_rewards')
          .doc();

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
    final userUid = getUserId();
    if (userUid == null) return;

    final userRef = _firestore.collection('users').doc(userUid);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
    final dailyStatsRef = userRef.collection('dailyStats').doc(today);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final int currentTotalPoints = (userSnapshot.data()?['totalPoints'] as int? ?? 0);

      transaction.set(userRef, {
        'totalPoints': currentTotalPoints + StepTracker.maxDailyPoints,
        'lastClaimedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(dailyStatsRef, {
        'claimedDailyBonus': true,
        'dailyPointsEarned': StepTracker.maxDailyPoints,
        'date': today,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<int> getTotalPointsFromUserProfile() async {
    final userUid = getUserId();
    if (userUid == null) return 0;

    final userProfileRef = _firestore.collection('users').doc(userUid);
    try {
      final userSnapshot = await userProfileRef.get();
      if (userSnapshot.exists) {
        return userSnapshot.data()?['totalPoints'] as int? ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      debugPrint('Error getting total points from user profile: $e');
      return 0;
    }
  }

  Future<void> setUserProfileStreak(int streak) async {
    final userUid = getUserId();
    if (userUid == null) return;

    final userRef = _firestore.collection('users').doc(userUid);
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

  Future<int> getUserProfileStreak() async {
    final userUid = getUserId();
    if (userUid == null) return 0;

    final userRef = _firestore.collection('users').doc(userUid);
    try {
      final snap = await userRef.get();
      return snap.data()?['currentStreak'] as int? ?? 0;
    } catch (e) {
      debugPrint('❌ getUserProfileStreak error: $e');
      return 0;
    }
  }

  Future<List<RedeemedRewardHistoryItem>> fetchRedeemedRewards() async {
    final userUid = getUserId();
    if (userUid == null) return [];

    try {
      final rewardRef = _firestore
          .collection('users')
          .doc(userUid)
          .collection('redeemed_rewards');

      final querySnapshot = await rewardRef.get();
      final rewardList = querySnapshot.docs.map((doc) {
        return RedeemedRewardHistoryItem.fromFirestore(doc.id, doc.data());
      }).toList();

      return rewardList;
    } catch (e) {
      debugPrint('Error fetching redeemed rewards: $e');
      return [];
    }
  }

  Future<List<AvailableRewardItem>> fetchAvailableRewards() async {
    try {
      final snapshot = await _firestore
          .collection('rewards_catalogue')
          .where('isActive', isEqualTo: true)
          .orderBy('rewardName')
          .get();

      return snapshot.docs
          .map((doc) => AvailableRewardItem.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching available rewards: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final userUid = getUserId();
    if (userUid == null) return null;

    final userRef = _firestore.collection('users').doc(userUid);
    try {
      final snap = await userRef.get();
      return snap.data();
    } catch (e) {
      debugPrint('❌ getUserProfile error: $e');
      return null;
    }
  }

  Future<void> updateUserName(String name) async {
    final userUid = getUserId();
    if (userUid == null) return;

    final userRef = _firestore.collection('users').doc(userUid);
    try {
      await userRef.set({
        'name': name,
        'nameUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ updateUserName → $name');
    } catch (e) {
      debugPrint('❌ updateUserName failed: $e');
      rethrow;
    }
  }

  /// 🟢 UPDATED: Added profileImageIndex field
  Future<void> createUserDocument({
    required String userUid,
    required String email,
    required int age,
  }) async {
    final userRef = _firestore.collection('users').doc(userUid);
    await userRef.set({
      'email': email,
      'age': age,
      'name': '',
      'totalPoints': 0,
      'currentStreak': 0,
      'lastClaimedDate': null,
      'lastRedeemedDate': null,
      'onboardingComplete': false,
      'profileImageIndex': 0, // 🟢 ADD THIS - Default profile image
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Created user document with default profile image index: 0');
  }

  Future<void> completeOnboarding() async {
    final userUid = getUserId();
    if (userUid == null) {
      debugPrint('❌ completeOnboarding: User not authenticated.');
      return;
    }

    final userRef = _firestore.collection('users').doc(userUid);
    try {
      await userRef.set({
        'onboardingComplete': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Onboarding marked as complete for user $userUid');
    } catch (e) {
      debugPrint('❌ completeOnboarding failed: $e');
      rethrow;
    }
  }
}
