import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart'; // Your main navigation widget
import 'package:myapp/features/step_tracker.dart';     // Your StepTracker provider
import 'package:myapp/theme/app_theme.dart';           // Your app's theme
import 'package:myapp/services/notification_service.dart'; // Your NotificationService
import 'package:timezone/data/latest.dart' as tz;       // Required for timezone initialization

// Instantiate your NotificationService globally for easy access
final NotificationService notificationService = NotificationService();

// IMPORTANT: The setupNotifications() function has been removed from here.
// Notification scheduling will now be handled within the UI (e.g., ProfilePage)
// after the user explicitly grants notification permissions.

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

 /// App entry point for Steps4Perks
  /// Notifications will be scheduled later after permissions are granted.
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