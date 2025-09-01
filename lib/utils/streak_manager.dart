import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StreakManager {
  static const int defaultStreakTarget = 10000; // 10k steps
  static const String _kLastEvaluatedFor = 'streak_last_evaluated_for';
  static const String _kCurrentStreak = 'currentStreak';

  /// Idempotently evaluates the streak for [todayDate] (yyyy-MM-dd, local time)
  /// based on **yesterday's** finalized step count.
  ///
  /// - If already evaluated for [todayDate], returns the stored streak.
  /// - If [yesterdaySteps] >= [streakTarget], increments the previous streak.
  /// - Otherwise, resets the streak to 0.
  Future<int> evaluate(
      String todayDate,
      SharedPreferences prefs,
      int yesterdaySteps, {
        int streakTarget = defaultStreakTarget,
      }) async {
    final lastEvaluatedFor = prefs.getString(_kLastEvaluatedFor);

    // If we've already evaluated streak for today, return existing value.
    if (lastEvaluatedFor == todayDate) {
      final cached = prefs.getInt(_kCurrentStreak) ?? 0;
      if (kDebugMode) {
        debugPrint('📊 StreakManager: already evaluated for $todayDate → $cached');
      }
      return cached;
    }

    final prevStreak = prefs.getInt(_kCurrentStreak) ?? 0;
    final metYesterday = yesterdaySteps >= streakTarget;

    final newStreak = metYesterday ? (prevStreak + 1) : 0;

    await prefs.setInt(_kCurrentStreak, newStreak);
    await prefs.setString(_kLastEvaluatedFor, todayDate);

    if (kDebugMode) {
      final y = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().toLocal().subtract(const Duration(days: 1)));
      debugPrint('📊 StreakManager evaluate()');
      debugPrint('  Today: $todayDate  | Yesterday: $y');
      debugPrint('  Yesterday steps: $yesterdaySteps  (target: $streakTarget)');
      debugPrint('  Prev streak: $prevStreak → New streak: $newStreak');
    }

    return newStreak;
  }

  /// Pure utility for unit tests.
  static int computeNextStreak(int prevStreak, bool metYesterday) {
    return metYesterday ? (prevStreak + 1) : 0;
  }
}
