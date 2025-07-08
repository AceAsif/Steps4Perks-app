import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart'; // Your main navigation widget
import 'package:myapp/features/step_tracker.dart';     // Your StepTracker provider
import 'package:myapp/theme/app_theme.dart';           // Your app's theme
import 'package:myapp/services/notification_service.dart'; // Your NotificationService
import 'package:timezone/data/latest.dart' as tz;       // Required for timezone initialization

// Instantiate your NotificationService globally for easy access
final NotificationService notificationService = NotificationService();

// You can put general comments about the app here at the file level
// or as a doc comment for the main function or MyApp class.

void main() async {
  // Ensure Flutter widgets binding is initialized before any Flutter-specific calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data for flutter_local_notifications' zonedSchedule
  tz.initializeTimeZones();

  // Initialize the notification plugin itself. This does NOT schedule notifications.
  await notificationService.initialize();

  // Run the app, providing the StepTracker ChangeNotifier
  runApp(
    ChangeNotifierProvider(
      create: (_) => StepTracker(),
      child: const MyApp(),
    ),
  );
  // Any code here after runApp() would typically not execute or cause issues.
  // Notifications will be scheduled later after permissions are granted.
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Apply your app's theme
      home: const Bottomnavigation(title: 'Steps4Perks'), // Your app's main entry point
    );
  }
}