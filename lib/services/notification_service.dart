import 'dart:math' as math;
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../main.dart';

// --- ADDED IMPORT ---
import 'package:myapp/widgets/profile_specific/notification_settings_dialog.dart'; // Make sure this path is correct

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Track if permissions have been requested
  bool _permissionsRequested = false;

  // --- REMOVED REDUNDANT VARIABLES ---
  // bool _notificationPromptDismissed = false;
  // int _retryCount = 0;
  // static const int _maxRetries = 2;

  Future<void> initialize() async {
    // Initialize the timezone database first
    tz.initializeTimeZones();
    debugPrint("✅ Timezones initialized");

    // Get the definitive local timezone name from the OS
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();

    // Set the local location for the timezone package
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('🌎 Local timezone set to: $timeZoneName');

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('🔔 Local notification tapped → Payload: ${response.payload}');
      },
      onDidReceiveBackgroundNotificationResponse:
      onDidReceiveBackgroundNotificationResponse,
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

    debugPrint('✅ NotificationService initialized successfully');
  }

  Future<void> _createNotificationChannels() async {
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
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

  /// ✅ FIXED: Request notification permissions with proper status checking
  /// Returns true if permission granted, false otherwise
  Future<bool> requestNotificationPermissions() async {
    // Check if already requested - return actual permission status
    if (_permissionsRequested) {
      debugPrint('⚠️ Notification permissions already requested, checking current status...');
      // Return the actual current permission status instead of false
      return await areNotificationsEnabled();
    }

    _permissionsRequested = true;
    try {
      debugPrint('🔔 Requesting notification permissions...');
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized;

      if (isAuthorized) {
        debugPrint('✅ Notification permissions granted');
        await _saveNotificationPreference(true);
      } else {
        debugPrint('❌ Notification permissions denied');
        await _saveNotificationPreference(false);
      }

      return isAuthorized;
    } catch (e, stack) {
      debugPrint('❌ Error requesting notification permissions: $e');
      debugPrint('Stack trace: $stack');
      return false;
    }
  }

  // --- REFACTORED THIS FUNCTION ---
  /// ✅ FIXED: Prompt user with "Go to Settings" dialog if denied
  /// Call this from your onboarding page after "Enable Notifications" is tapped
  Future<bool> requestNotificationsWithPrompt(BuildContext context) async {
    debugPrint('🔔 Requesting notifications with prompt...');

    // Request permissions first
    final granted = await requestNotificationPermissions();

    if (granted) {
      // Permissions granted - show success message
      _permissionsRequested = true; // Ensure flag is set
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Notifications enabled successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } else {
      // Permissions denied - show the "Go to Settings" dialog
      if (context.mounted) {
        // Use the correct dialog you already created!
        await showNotificationSettingsDialog(context);
      }
      // Permission was not granted
      return false;
    }
  }

  // --- DELETED THE _showNotificationDisabledDialog FUNCTION ---

  /// Save notification preference to SharedPreferences
  Future<void> _saveNotificationPreference(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', enabled);
      debugPrint('💾 Notification preference saved: $enabled');
    } catch (e) {
      debugPrint('❌ Error saving notification preference: $e');
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      // Check both SharedPreferences and actual system permission
      final prefs = await SharedPreferences.getInstance();
      final savedPref = prefs.getBool('notificationsEnabled') ?? false;

      // Also check actual Firebase permission status
      final settings = await _firebaseMessaging.getNotificationSettings();
      final systemEnabled = settings.authorizationStatus == AuthorizationStatus.authorized;

      // Return true only if both are enabled
      final result = savedPref && systemEnabled;
      debugPrint("📊 Notifications enabled check - Saved: $savedPref, System: $systemEnabled, Result: $result");
      return result;
    } catch (e) {
      debugPrint('❌ Error checking notification preference: $e');
      return false;
    }
  }

  // --- UPDATED THIS FUNCTION ---
  /// Reset permissions request flag (for testing/debugging)
  void resetPermissionsFlag() {
    _permissionsRequested = false;
    debugPrint('🔄 Permissions request flags reset');
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
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    final nowPlusSomeBuffer = now.add(const Duration(seconds: 5));
    if (scheduled.isBefore(nowPlusSomeBuffer)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}