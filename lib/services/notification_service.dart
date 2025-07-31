import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Still useful for general permission status checks
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initialize the notification plugin + timezone setup + FCM listeners
  /// This method sets up listeners and gets the FCM token, but doesn't
  /// explicitly trigger the permission prompt. Use requestNotificationPermissions() for that.
  Future<void> initialize() async {
    tz.initializeTimeZones();
    debugPrint("✅ Timezones initialized for local notifications.");

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
        // This handler runs when the app is in the foreground
        debugPrint('🔔 Local Notification Tapped (Foreground) → Payload: ${response.payload}');
      },
      // <--- IMPORTANT CHANGE HERE --->
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse, // <--- Use the top-level function
      // <--- END IMPORTANT CHANGE --->
    );
    debugPrint("✅ FlutterLocalNotificationsPlugin initialized.");

    // --- FCM Setup ---
    // Only get the token and set up message listeners here.
    // The explicit permission request is now in requestNotificationPermissions()
    String? token = await _firebaseMessaging.getToken();
    debugPrint("FCM Token: $token");
    // Send this token to your backend server if needed

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a FCM message whilst in the foreground!');
      debugPrint('FCM Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('FCM Message also contained a notification: ${message.notification}');
        _notificationsPlugin.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fcm_default_channel',
              'FCM Notifications',
              channelDescription: 'General notifications from Firebase Cloud Messaging',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          payload: message.data['payload_key'] ?? message.notification?.title,
        );
      }
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("App opened from terminated state by FCM notification: ${initialMessage.data}");
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background by FCM notification: ${message.data}');
    });

    debugPrint("✅ NotificationService initialized with FCM setup complete.");
  }

  // <--- RE-DEFINED PUBLIC METHOD FOR REQUESTING PERMISSIONS --->
  /// Requests notification permissions from the system.
  /// This method specifically triggers the system permission dialog.
  /// Returns true if permission is granted, false otherwise.
  Future<bool> requestNotificationPermissions() async {
    // For Android 13+ and iOS, FirebaseMessaging.requestPermission is the way to go.
    // It handles the underlying system prompts for both platforms.
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Check authorizationStatus to determine if granted
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
  // <--- END RE-DEFINED PUBLIC METHOD --->

  // You can add a method to get the FCM token if needed elsewhere
  Future<String?> getFCMToken() async {
    final String? token = await _firebaseMessaging.getToken(); // Fetch the token
    debugPrint("FCM Token (from getFCMToken method): $token"); // <--- ADDED DEBUG PRINT HERE
    return token; // Return the token
  }

  /// Show an immediate notification (for testing/debugging)
  Future<void> showImmediateNotification({String? title, String? body}) async {
    await _notificationsPlugin.show(
      111,
      title ?? '🚨 Immediate Test',
      body ?? 'This is an immediate test notification.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'immediate_test_channel',
          'Immediate Test',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    debugPrint("✅ Immediate local notification sent.");
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
    debugPrint('📅 Scheduling Local Notification → $title at $scheduledTime');

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
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("✅ Local Notification scheduled successfully for $scheduledTime");
  }

  /// Schedules a daily reminder (wrapper for your app logic)
  Future<void> scheduleDailyReminderOnce({
    required int hour,
    required int minute,
  }) async {
    await scheduleNotification(
      id: 100,
      title: '🚶 Daily Reminder',
      body: 'Remember to walk and earn points!',
      hour: hour,
      minute: minute,
    );
  }

  Future<void> resetDailyReminderFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dailyReminderScheduled', false);
  }

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