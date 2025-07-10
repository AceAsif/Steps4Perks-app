import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart'; // Your main navigation widget
import 'package:myapp/features/step_tracker.dart'; // Your StepTracker provider
import 'package:myapp/theme/app_theme.dart'; // Your app's theme
import 'package:myapp/services/notification_service.dart'; // Your NotificationService
import 'package:timezone/data/latest.dart'
    as tz; // Required for timezone initialization
import 'package:timezone/timezone.dart' as tz;

// IMPORTANT: Import flutter_local_notifications for NotificationResponse type
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Instantiate your NotificationService globally for easy access
final NotificationService notificationService = NotificationService();

// THIS IS THE MISSING TOP-LEVEL FUNCTION
// It must be marked with @pragma('vm:entry-point') to ensure it's accessible
// by the Flutter engine when a notification is tapped in the background/terminated state.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // This function is executed when a notification is tapped while the app
  // is in the background or terminated.
  debugPrint(
    'Background notification tapped! Payload: ${notificationResponse.payload}',
  );

  // You can add logic here to:
  // - Navigate to a specific screen based on the payload.
  // - Log the event.
  // - Perform background tasks (e.g., update a badge count, fetch data).
  //
  // If you need to use Flutter widgets or services that require initialization
  // (like SharedPreferences, or even re-scheduling notifications), you might
  // need to call WidgetsFlutterBinding.ensureInitialized() and re-initialize
  // your services here. For example:
  // WidgetsFlutterBinding.ensureInitialized();
  // NotificationService().initialize(); // Re-initialize if needed for background operations
}

void main() async {
  // Ensure Flutter widgets binding is initialized before any Flutter-specific calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data for flutter_local_notifications' zonedSchedule
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  // Initialize the notification plugin itself. This does NOT schedule notifications.
  // The `notificationTapBackground` function is passed to its `initialize` method
  // in `notification_service.dart`.
  await notificationService.initialize();

  // Run the app, providing the StepTracker ChangeNotifier
  runApp(
    ChangeNotifierProvider(create: (_) => StepTracker(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: true, //for debugging purpose
      theme: AppTheme.lightTheme, // Apply your app's theme
      home: const Bottomnavigation(
        title: 'Steps4Perks',
      ), // Your app's main entry point
    );
  }
}
