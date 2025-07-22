import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/view/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// GENERATED Firebase config
import 'firebase_options.dart';

final NotificationService notificationService = NotificationService();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Background notification tapped! Payload: ${notificationResponse.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint('✅ Firebase initialized and signed in anonymously.');
  } catch (e, stacktrace) {
    debugPrint('❌ Firebase initialization error: $e');
    debugPrint('🔍 Stacktrace: $stacktrace');
  }

  tz.initializeTimeZones();
  await notificationService.initialize();

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
      title: 'LoopXP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}