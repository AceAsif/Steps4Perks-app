import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/services/database_service.dart';

class StreakManager {
  // ---- Constants / Keys ----
  static const int defaultStreakTarget = 10000; // 10k steps

  // Local cache keys
  static const String _kLastEvaluatedFor = 'streak_last_evaluated_for';
  static const String _kCurrentStreak   = 'currentStreak';

  // "Which date did we already credit a streak increment for?"
  // Used to avoid double-incrementing once today passes the target.
  static const String _kStreakCreditedFor = 'streakCreditedFor';

  /// Helper: yyyy-MM-dd (local)
  static String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d.toLocal());
  static String todayStr() => _fmt(DateTime.now());
  static String yesterdayStr() => _fmt(DateTime.now().subtract(const Duration(days: 1)));

  // ---------------------------------------------------------------------------
  // A) Morning/new-day evaluation (based on **yesterday’s** finalized steps)
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
    final lastEvaluatedFor = prefs.getString(_kLastEvaluatedFor);
    if (lastEvaluatedFor == today) {
      final cached = prefs.getInt(_kCurrentStreak) ?? 0;
      if (kDebugMode) {
        debugPrint('📊 StreakManager: already evaluated for $today → $cached');
      }
      // Also clear credit flag for today (safety) so we can credit again later if needed
      await prefs.remove(_kStreakCreditedFor);
      return cached;
    }

    final String y = yesterdayStr();

    // Short-circuit: if we already credited **yesterday**, then we know yesterday met the target.
    final bool creditedYesterday = (prefs.getString(_kStreakCreditedFor) == y);
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
        newStreak = prefs.getInt(_kCurrentStreak) ?? 0;
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

    await prefs.setInt(_kCurrentStreak, newStreak);
    await prefs.setString(_kLastEvaluatedFor, today);
    // New day → clear today’s credit marker
    await prefs.remove(_kStreakCreditedFor);

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

    final creditedFor = prefs.getString(_kStreakCreditedFor);
    if (creditedFor == today) {
      // Already credited today; nothing to do.
      return currentStreak;
    }

    // Credit once
    final int newStreak = currentStreak + 1;
    await prefs.setInt(_kCurrentStreak, newStreak);
    await prefs.setString(_kStreakCreditedFor, today);

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
  // C) Pure utility (kept from your original for tests)
  // ---------------------------------------------------------------------------
  static int computeNextStreak(int prevStreak, bool metYesterday) {
    return metYesterday ? (prevStreak + 1) : 0;
  }
}
