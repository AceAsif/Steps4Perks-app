import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class StreakManager {
  static const int dailyStepGoal = 3000;

  Future<int> evaluate(String today, SharedPreferences prefs, int stepsToday) async {
    final lastGoalDate = prefs.getString('lastStepGoalDate') ?? '';
    int streak = prefs.getInt('currentStreak') ?? 0;

    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    debugPrint('📊 Evaluating streak...');
    debugPrint('Today: $today');
    debugPrint('Steps today: $stepsToday');
    debugPrint('Last goal date: $lastGoalDate');
    debugPrint('Current streak: $streak');

    // ✅ 1. Today’s goal met and not already counted
    if (stepsToday >= dailyStepGoal && lastGoalDate != today) {
      if (lastGoalDate == yesterday) {
        streak += 1; // Continue streak
      } else {
        streak = 1; // Start new streak
      }

      await prefs.setInt('currentStreak', streak);
      await prefs.setString('lastStepGoalDate', today);

      debugPrint('✅ Streak updated: $streak');
    }

    // ❗️ 2. Check if streak needs resetting (missed goal yesterday)
    if (lastGoalDate != yesterday && lastGoalDate != today) {
      // Missed yesterday's goal
      streak = 0;
      await prefs.setInt('currentStreak', streak);
      debugPrint('❌ Streak reset: goal not met yesterday ($yesterday)');
    }

    return streak;
  }
}
