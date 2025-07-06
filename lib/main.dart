import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/services/notification_service.dart';

final notificationService = NotificationService();

Future<void> setupNotifications() async {
  await notificationService.scheduleDailyReminder(hour: 10, minute: 0);

  // TODO: Move these into Settings later.
  await notificationService.scheduleNotification(
    id: 1,
    title: '🌞 Morning Walk',
    body: 'Start your day with a refreshing walk!',
    hour: 7,
    minute: 30,
  );

  await notificationService.scheduleNotification(
    id: 2,
    title: '🍱 Lunch Walk',
    body: 'Stretch your legs after lunch.',
    hour: 12,
    minute: 30,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notificationService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => StepTracker(),
      child: const MyApp(),
    ),
  );

  await setupNotifications();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const Bottomnavigation(title: 'Steps4Perks'),
    );
  }
}
