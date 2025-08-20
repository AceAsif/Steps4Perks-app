import 'dart:math' as math;
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; // <--- ADDED IMPORT

import '../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Initialize the timezone database first
    tz.initializeTimeZones();
    debugPrint("✅ Timezones initialized");

    // <--- ADDED EXPLICIT TIMEZONE SETTING FOR ROBUSTNESS --->
    // Get the definitive local timezone name from the OS
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    // Set the local location for the timezone package
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('🌎 Local timezone set to: $timeZoneName');
    // <--- END ADDED EXPLICIT TIMEZONE SETTING --->

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('🔔 Local notification tapped → Payload: ${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    await _createNotificationChannels();

    final fcmToken = await _firebaseMessaging.getToken();
    debugPrint("📱 FCM Token: $fcmToken");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _notificationsPlugin.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fcm_default_channel',
              'FCM Notifications',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
          ),
        );
      }
    });
  }

  Future<void> _createNotificationChannels() async {
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        'scheduled_reminder_channel',
        'Scheduled Reminders',
        description: 'Daily scheduled reminders',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        'immediate_test_channel',
        'Immediate Test',
        description: 'Test notifications immediately',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'fcm_default_channel',
        'FCM Notifications',
        description: 'Firebase Cloud Messaging push notifications',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await android.createNotificationChannel(
      AndroidNotificationChannel(
        'scheduled_channel',
        'Scheduled Notifications',
        description: 'One-time scheduled notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  Future<bool> requestNotificationPermissions() async {
    final settings = await _firebaseMessaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint("🗑️ All notifications cancelled.");
  }

  Future<void> showImmediateNotification({
    String title = '🚀 Test Notification',
    String body = 'This is a test.',
  }) async {
    await _notificationsPlugin.show(
      111,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'immediate_test_channel',
          'Immediate Test',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
    debugPrint("✅ Immediate notification shown.");
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final time = _nextInstanceOfTime(hour, minute);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      time,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_reminder_channel',
          'Scheduled Reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("⏰ Scheduled notification for $time");
  }

  Future<void> scheduleDailyReminderOnce({
    required int hour,
    required int minute,
    required AndroidScheduleMode scheduleMode,
  }) async {
    await scheduleNotification(
      id: 100,
      title: '🏃 Daily Reminder',
      body: 'Remember to walk and earn your reward!',
      hour: hour,
      minute: minute,
      scheduleMode: scheduleMode,
    );
  }

  Future<int> zonedScheduleNotification({
    required String note,
    required DateTime date,
    required String occ,
  }) async {
    final id = math.Random().nextInt(10000);
    final scheduledDate = tz.TZDateTime.from(date, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      log("❌ Cannot schedule notification in the past.");
      return -1;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        occ,
        note,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_channel',
            'Scheduled Notifications',
            playSound: true,
            enableVibration: true,
            largeIcon: DrawableResourceAndroidBitmap("logo"),
            icon: "ic_launcher",
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      return id;
    } catch (e) {
      log("❌ Scheduling error: $e");
      return -1;
    }
  }

  Future<void> resetDailyReminderFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminderScheduled', false);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    final nowPlusSomeBuffer = now.add(const Duration(seconds: 5));

    if (scheduled.isBefore(nowPlusSomeBuffer)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
