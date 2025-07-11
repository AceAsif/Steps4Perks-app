import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io'; //This is need for understanding the os platform
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize the notification plugin + timezone setup
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('🔔 Notification Tapped → Payload: ${response.payload}');
      },
    );

    // tz.initializeTimeZones(); // Required for scheduling with timezones
    debugPrint("✅ NotificationService initialized with timezone setup.");
  }

  Future<bool> requestNotificationPermissions() async {
    // For now, only Android 13+ and iOS need permission requests
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true; // Auto-granted below Android 13
    } else if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return false;
  }

  /// Show an immediate notification (for testing/debugging)
  Future<void> showImmediateNotification() async {
    await _notificationsPlugin.show(
      111,
      '🚨 Immediate Test',
      'This is an immediate test notification.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'immediate_test_channel',
          'Immediate Test',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    debugPrint("✅ Immediate notification sent.");
  }

  /// Schedule a daily notification at a specific hour & minute
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);
    debugPrint('📅 Scheduling Notification → $title at $scheduledTime');

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_reminder_channel',
          'Scheduled Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeats daily
    );

    debugPrint("✅ Notification scheduled successfully for $scheduledTime");
  }

  /// Schedules a daily reminder (wrapper for your app logic)
  Future<void> scheduleDailyReminderOnce({
    required int hour,
    required int minute,
  }) async {
    await scheduleNotification(
      id: 100, // Use a unique ID for daily reminder
      title: '🚶 Daily Reminder',
      body: 'Remember to walk and earn points!',
      hour: hour,
      minute: minute,
    );
  }

  // Add inside your NotificationService class:
  Future<void> resetDailyReminderFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminderScheduled', false);
  }

  /// Helper method for calculating next instance of given time (for today or tomorrow)
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
