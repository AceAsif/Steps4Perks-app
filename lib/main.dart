import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'firebase_options.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/features/profile_image_provider.dart';
import 'package:myapp/services/notification_service.dart';

import 'package:myapp/view/splash_screen.dart';
import 'package:myapp/view/onboardingpage.dart';
import 'package:myapp/view/auth/login_page.dart';
import 'package:myapp/view/auth/signup_page.dart';
import 'package:myapp/features/bottomnavigation.dart';

final NotificationService notificationService = NotificationService();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔔 Background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse notificationResponse) {
  debugPrint('🔔 Local Background Notification tapped → Payload: ${notificationResponse.payload}');
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('🔔 Local Notification tapped! Payload: ${notificationResponse.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('✅ Firebase initialized.');

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboardingComplete') ?? false;

  try {
    tz.initializeTimeZones();
    debugPrint('✅ Timezones initialized.');
  } catch (e) {
    debugPrint('❌ Timezone init error: $e');
  }

  try {
    await notificationService.initialize();
    debugPrint('✅ NotificationService initialized.');
  } catch (e) {
    debugPrint('❌ NotificationService init error: $e');
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
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(onboardingComplete: onboardingComplete),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/onboarding': (context) => const OnboardingPage(),
        '/home': (context) => const Bottomnavigation(title: 'Steps4Perks'),
      },
    );
  }
}

/// ✅ UPDATED: Handles Firebase auth and onboarding state
/// Now always shows LoginPage when user is logged out
class AuthGate extends StatelessWidget {
  final bool onboardingComplete;
  const AuthGate({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for Firebase to initialize
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen(onboardingComplete: onboardingComplete);
        }

        // User is logged in
        if (snapshot.hasData) {
          return onboardingComplete
              ? const Bottomnavigation(title: 'Steps4Perks')
              : const OnboardingPage();
        }

        // ✅ User is not signed in → ALWAYS show LoginPage
        // This ensures logout always takes you to login page
        return const LoginPage();
      },
    );
  }
}
