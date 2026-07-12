import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:steps4perks/services/sync_manager.dart';
import 'package:steps4perks/services/database_service.dart';

class LogoutService {
  static final LogoutService _instance = LogoutService._internal();

  factory LogoutService() => _instance;
  LogoutService._internal();

  final _syncManager = SyncManager();
  final _databaseService = DatabaseService();

  /// 🟢 CRITICAL: Complete logout with final sync
  Future<bool> logoutWithSync({
    required int dailySteps,
    required int totalPoints,
    required int currentStreak,
    required bool hasClaimedToday,
  }) async {
    debugPrint('🔴 LOGOUT: Starting final sync before logout...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️  No user to log out');
        return true;
      }

      // 🟢 STEP 1: Sync pending updates via SyncManager
      debugPrint('⏳ LOGOUT: Step 1 - Syncing pending updates...');
      final syncSuccess = await _syncManager.syncNow(forceWrite: true);
      if (!syncSuccess) {
        debugPrint('⚠️  LOGOUT: SyncManager sync had issues but continuing...');
      }

      // 🟢 STEP 2: Save daily stats to database
      debugPrint('⏳ LOGOUT: Step 2 - Saving daily stats...');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now().toLocal());
      try {
        await _databaseService.saveStatsAndPoints(
          date: today,
          steps: dailySteps,
          dailyPointsEarned: dailySteps ~/ 100,
          streak: currentStreak,
          claimedDailyBonus: hasClaimedToday,
        );
        debugPrint('✅ LOGOUT: Daily stats saved');
      } catch (e) {
        debugPrint('❌ LOGOUT: Failed to save daily stats: $e');
      }

      // 🟢 STEP 3: Update user profile with latest data
      debugPrint('⏳ LOGOUT: Step 3 - Updating user profile...');
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'dailySteps': dailySteps,
          'totalPoints': totalPoints,
          'currentStreak': currentStreak,
          'lastSyncedAt': FieldValue.serverTimestamp(),
          'lastLogoutTime': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ LOGOUT: User profile updated');
      } catch (e) {
        debugPrint('❌ LOGOUT: Failed to update user profile: $e');
      }

      // 🟢 STEP 4: Sign out from Firebase
      debugPrint('⏳ LOGOUT: Step 4 - Signing out from Firebase...');
      await FirebaseAuth.instance.signOut();
      debugPrint('✅ LOGOUT: Signed out successfully');

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ LOGOUT: Error during logout: $e');
      debugPrint('Stack: $stackTrace');

      // Still sign out even if sync failed
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      return false;
    }
  }
}
