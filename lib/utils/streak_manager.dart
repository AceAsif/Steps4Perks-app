import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:steps4perks/services/database_service.dart';

class StreakManager {
  // ---- Constants / Keys ----
  static const int defaultStreakTarget = 10000; // 10k steps

  // Local cache keys (base names — namespaced per user, see _key())
  static const String _kLastEvaluatedFor = 'streak_last_evaluated_for';
  static const String _kCurrentStreak = 'currentStreak';

  // "Which date did we already credit a streak increment for?"
  // Used to avoid double-incrementing once today passes the target.
  static const String _kStreakCreditedFor = 'streakCreditedFor';

  /// 🟢 FIX: Namespace keys per user, matching StepTracker._getPrefsKey().
  /// Previously StreakManager wrote plain 'currentStreak' while StepTracker
  /// read '${uid}_currentStreak' — the two never saw each other's values,
  /// and streak state leaked between accounts on a shared device.
  static String _key(String base) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return base;
    return '${userId}_$base';
  }

  /// Helper: yyyy-MM-dd (local)
  static String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());
  static String todayStr() => _fmt(DateTime.now());
  static String yesterdayStr() => _fmt(DateTime.now().subtract(const Duration(days: 1)));

  // ---------------------------------------------------------------------------
  // A) Morning/new-day evaluation (based on **yesterday's** finalized steps)
  // ---------------------------------------------------------------------------
  /// Idempotently evaluate the streak for [today].
  ///
  /// Logic:
  /// - If we already evaluated for [today], return cached streak.
  /// - Otherwise, check if **yesterday** met [streakTarget]:
  ///     * YES  -> keep previous streak as-is (do not increment here)
  ///     * NO   -> reset streak to 0
  /// - Persist streak to prefs + Firestore user profile.
  /// - Clear today's "credited" flag (so we can credit later when today hits target).
  ///
  /// Returns the up-to-date streak value.
  static Future<int> evaluateForNewDay({
    required String today,
    required SharedPreferences prefs,
    required DatabaseService db,
    int streakTarget = defaultStreakTarget,
  }) async {
    // If already evaluated, just return cached
    final lastEvaluatedFor = prefs.getString(_key(_kLastEvaluatedFor));
    if (lastEvaluatedFor == today) {
      final cached = prefs.getInt(_key(_kCurrentStreak)) ?? 0;
      if (kDebugMode) {
        debugPrint('📊 StreakManager: already evaluated for $today → $cached');
      }
      return cached;
    }

    final String y = yesterdayStr();

    // Short-circuit: if we already credited **yesterday**, then we know yesterday met the target.
    final bool creditedYesterday = (prefs.getString(_key(_kStreakCreditedFor)) == y);
    bool metYesterday = creditedYesterday;

    if (!creditedYesterday) {
      // Look up yesterday's steps from DB
      int yesterdaySteps = 0;
      try {
        final yDoc = await db.getDailyStatsOnce(y);
        if (yDoc != null) {
          final s = yDoc['steps'];
          if (s is int) {
            yesterdaySteps = s;
          } else if (s is double) {
            yesterdaySteps = s.toInt();
          }
        }
      } catch (_) {}
      metYesterday = yesterdaySteps >= streakTarget;
    }

    // Compute new streak (do NOT increment here — that happens when TODAY hits target)
    int newStreak;
    if (metYesterday) {
      // keep existing streak (from DB if present, else local)
      newStreak = await db.getUserProfileStreak();
      if (newStreak == 0) {
        newStreak = prefs.getInt(_key(_kCurrentStreak)) ?? 0;
      }
      if (kDebugMode) {
        debugPrint('✅ StreakManager: yesterday met → keep streak $newStreak');
      }
    } else {
      newStreak = 0;
      await db.setUserProfileStreak(0);
      if (kDebugMode) {
        debugPrint('❌ StreakManager: yesterday missed → reset streak to 0');
      }
    }

    await prefs.setInt(_key(_kCurrentStreak), newStreak);
    await prefs.setString(_key(_kLastEvaluatedFor), today);
    // New day → clear today's credit marker
    await prefs.remove(_key(_kStreakCreditedFor));

    return newStreak;
  }

  // ---------------------------------------------------------------------------
  // B) Live crediting when TODAY crosses the target
  // ---------------------------------------------------------------------------
  /// If today's step count crosses [streakTarget] and we haven't credited **today**
  /// yet, increment streak once, persist to prefs + Firestore, and also write
  /// today's dailyStats with updated [streak] (idempotent due to "creditedFor" flag).
  ///
  /// Returns the (possibly updated) streak.
  static Future<int> tryCreditTodayIfTargetMet({
    required int todaySteps,
    required int dailyPointsEarned,
    required bool hasClaimedBonus,
    required String today,
    required int currentStreak,
    required SharedPreferences prefs,
    required DatabaseService db,
    int streakTarget = defaultStreakTarget,
  }) async {
    if (todaySteps < streakTarget) return currentStreak;

    final creditedFor = prefs.getString(_key(_kStreakCreditedFor));
    if (creditedFor == today) {
      // Already credited today; nothing to do.
      return currentStreak;
    }

    // Credit once
    final int newStreak = currentStreak + 1;
    await prefs.setInt(_key(_kCurrentStreak), newStreak);
    await prefs.setString(_key(_kStreakCreditedFor), today);

    await db.setUserProfileStreak(newStreak);
    // Also persist today's stats snapshot (merge) so UI/DB stay consistent.
    await db.saveStatsAndPoints(
      date: today,
      steps: todaySteps,
      dailyPointsEarned: dailyPointsEarned,
      streak: newStreak,
      claimedDailyBonus: hasClaimedBonus,
    );

    if (kDebugMode) {
      debugPrint('🔥 StreakManager: credited $today → streak = $newStreak');
    }
    return newStreak;
  }

  // ---------------------------------------------------------------------------
  // C) Pure utility (kept for tests)
  // ---------------------------------------------------------------------------
  static int computeNextStreak(int prevStreak, bool metYesterday) {
    return metYesterday ? (prevStreak + 1) : 0;
  }
}
