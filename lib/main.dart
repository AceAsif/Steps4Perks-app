import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/view/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// GENERATED Firebase config
import 'firebase_options.dart';

// Instantiate your NotificationService (it's a singleton, so this is fine)
final NotificationService notificationService = NotificationService();

// Existing: TOP-LEVEL FCM BACKGROUND MESSAGE HANDLER
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint("Background message data: ${message.data}");
}

// NEW: TOP-LEVEL LOCAL NOTIFICATION BACKGROUND RESPONSE HANDLER
@pragma('vm:entry-point') // Required for Flutter background isolates
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  debugPrint('🔔 Local Background Notification Tapped → Payload: ${notificationResponse.payload}');
  // You can add more complex logic here (e.g., navigating to a specific screen)
}

// Existing: TOP-LEVEL LOCAL NOTIFICATION FOREGROUND RESPONSE HANDLER (from main.dart)
// This function is for local notification taps when the app is in the background/terminated.
// It's separate from FCM's background handler.
// This one is already good.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Local Background notification tapped! Payload: ${notificationResponse.payload}');
}

void main() async {
  // Ensure Flutter engine is initialized before any plugins are used
  WidgetsFlutterBinding.ensureInitialized();

  // --- 1. Initialize Firebase for the main app isolate ---
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized for main app.');
  } catch (e) {
    debugPrint('❌ Firebase initialization error for main app: $e');
    // If Firebase initialization fails, the app might not function correctly.
    // You might consider showing a fatal error screen or rethrowing in a production app.
    // For debugging, it will just log and continue.
  }

  // --- 2. Register the FCM background message handler BEFORE runApp() ---
  // This is crucial for receiving messages when the app is terminated.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- 3. Initialize timezone data for flutter_local_notifications ---
  try {
    tz.initializeTimeZones();
    debugPrint('✅ Timezones initialized.');
  } catch (e) {
    debugPrint('❌ Timezone initialization error: $e');
    // This error might prevent scheduled local notifications from working correctly.
  }

  // --- 4. Initialize your NotificationService ---
  // This service includes both local notifications setup and FCM message listeners.
  try {
    await notificationService.initialize();
    debugPrint('✅ NotificationService initialized.');
  } catch (e) {
    debugPrint('❌ NotificationService initialization error: $e');
    // If this fails, notifications (local and push) won't work, but the app might still run.
  }

  // --- 5. Run the Flutter application ---
  runApp(
    ChangeNotifierProvider(
      create: (_) => StepTracker(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(), // Your app's entry point UI
    );
  }
}