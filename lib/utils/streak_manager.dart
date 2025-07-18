import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakManager {
  static const int dailyStepGoal = 3000;

  Future<int> evaluate(String today, SharedPreferences prefs, int stepsToday) async {
    final lastGoalDate = prefs.getString('lastStepGoalDate') ?? '';
    int streak = prefs.getInt('currentStreak') ?? 0;

    if (stepsToday >= dailyStepGoal && lastGoalDate != today) {
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      streak = (lastGoalDate == yesterday) ? streak + 1 : 1;

      await prefs.setInt('currentStreak', streak);
      await prefs.setString('lastStepGoalDate', today);
    } else if (stepsToday < dailyStepGoal && lastGoalDate != today) {
      streak = 0;
      await prefs.setInt('currentStreak', streak);
    }

    return streak;
  }
}
