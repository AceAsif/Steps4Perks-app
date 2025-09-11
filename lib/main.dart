import 'package:flutter/material.dart';
import 'package:myapp/view/app_shell.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/features/profile_image_provider.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/view/splash_screen.dart';
import 'package:myapp/view/onboardingpage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/view/auth_page.dart'; // ✅ Added the import for AuthPage

import 'firebase_options.dart';

final NotificationService notificationService = NotificationService();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  debugPrint('🔔 Local Background Notification Tapped → Payload: ${notificationResponse.payload}');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Local Background notification tapped! Payload: ${notificationResponse.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized for main app.');

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

  try {
    tz.initializeTimeZones();
    debugPrint('✅ Timezones initialized.');
  } catch (e) {
    debugPrint('❌ Timezone initialization error: $e');
  }

  try {
    await notificationService.initialize();
    debugPrint('✅ NotificationService initialized.');
  } catch (e) {
    debugPrint('❌ NotificationService initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StepTracker()),
        ChangeNotifierProvider(create: (_) => ProfileImageProvider()),
      ],
      child: MyApp(onboardingComplete: onboardingComplete),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool onboardingComplete;

  const MyApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(onboardingComplete: onboardingComplete),
    );
  }
}

// A new widget to handle the authentication and onboarding logic
class AuthGate extends StatelessWidget {
  final bool onboardingComplete;
  const AuthGate({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading screen while we wait for Firebase to initialize
        if (snapshot.connectionState == ConnectionState.waiting) {
          // ✅ FIX: Pass the required onboardingComplete parameter
          return SplashScreen(onboardingComplete: onboardingComplete);
        }

        // If the user is signed in (User object is not null)
        if (snapshot.hasData) {
          // If onboarding is complete, go to the main app page
          if (onboardingComplete) {
            return const AppShell();
          } else {
            // Otherwise, show the new onboarding screen
            return const OnboardingPageNew();
          }
        } else {
          // If the user is not signed in, show the AuthPage
          return const AuthPage();
        }
      },
    );
  }
}
