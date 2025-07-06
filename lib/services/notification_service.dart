import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(settings);
    tz.initializeTimeZones();
  }

  /// Standard daily reminder scheduling.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0, // Notification ID
      '🚶 Time to Walk!',
      'Take a walk today and earn points!',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel_id',
          'Daily Reminder',
          channelDescription: 'Reminder to walk daily',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // ✅ Required
      matchDateTimeComponents: DateTimeComponents.time, // 🔑 Repeat Daily
    );
  }

  /*This method:
    - Lets you send custom daily notifications at any hour/minute.
    - Accepts unique ID, title, and body.
    - Repeats daily.
  */
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'custom_reminder_channel_id',
          'Custom Reminders',
          channelDescription: 'User custom reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Safe scheduling (only schedules once).
  Future<void> scheduleDailyReminderOnce({
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isScheduled = prefs.getBool('dailyReminderScheduled') ?? false;

    if (!isScheduled) {
      await scheduleDailyReminder(hour: hour, minute: minute);
      await prefs.setBool('dailyReminderScheduled', true);
    }
  }

  /// Optional: Force reset the reminder flag.
  Future<void> resetDailyReminderFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminderScheduled', false);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
