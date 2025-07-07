import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

/// ✅ REQUIRED: Background Handler (MUST be top-level)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Notification tapped in background: ${notificationResponse.payload}');
}

/// ✅ Notification Service Singleton
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        debugPrint('Notification tapped (foreground): ${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    tz.initializeTimeZones();
  }

  /// ✅ Request Notification Permission (cross-platform)
  Future<bool> requestNotificationPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true; // Auto-granted below Android 13
    } else if (Platform.isIOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  /// ✅ Check if Notification Permission Granted
  Future<bool> isNotificationPermissionGranted() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    return false;
  }

  /// ✅ Schedule a daily reminder at fixed time
  Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      0,
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// ✅ Custom Daily Notification (multiple reminders)
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

  /// ✅ One-time safe scheduling (only schedules once)
  Future<void> scheduleDailyReminderOnce({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    final isScheduled = prefs.getBool('dailyReminderScheduled') ?? false;
    if (!isScheduled) {
      await scheduleDailyReminder(hour: hour, minute: minute);
      await prefs.setBool('dailyReminderScheduled', true);
    }
  }

  /// ✅ Reset the reminder flag
  Future<void> resetDailyReminderFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminderScheduled', false);
  }

  /// ✅ Helper for correct scheduling
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
