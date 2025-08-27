import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/services/notification_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notification Reminders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                await NotificationService().scheduleNotification(
                  id: 1,
                  title: '🌞 Morning Walk',
                  body: 'Start your day with a refreshing walk!',
                  hour: 7,
                  minute: 30,
                  scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                );
                if (context.mounted) {
                  _showSnackBar(context, 'Morning reminder scheduled!');
                }
              },
              icon: const Icon(Icons.wb_sunny),
              label: const Text('Schedule Morning Reminder'),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () async {
                await NotificationService().scheduleNotification(
                  id: 2,
                  title: '🍱 Lunch Walk',
                  body: 'Time for a walk after lunch!',
                  hour: 12,
                  minute: 30,
                  scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                );
                if (context.mounted) {
                  _showSnackBar(context, 'Lunch reminder scheduled!');
                }
              },
              icon: const Icon(Icons.lunch_dining),
              label: const Text('Schedule Lunch Reminder'),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () async {
                await NotificationService().scheduleNotification(
                  id: 3,
                  title: '🌙 Evening Wrap-up',
                  body: 'Finish your steps before the day ends!',
                  hour: 19,
                  minute: 0,
                  scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                );
                if (context.mounted) {
                  _showSnackBar(context, 'Evening reminder scheduled!');
                }
              },
              icon: const Icon(Icons.nightlight_round),
              label: const Text('Schedule Evening Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
