import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/notification_service.dart';

class DebugToolsPage extends StatelessWidget {
  const DebugToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      // Prevent access if not in debug mode
      return const Scaffold(
        body: Center(
          child: Text(
            '🚫 Debug Tools Only Available in Debug Mode',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🐞 Debug Tools'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07, vertical: screenHeight * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notification Testing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now();
                final testHour = now.hour;
                final testMinute = now.minute + 1;

                await NotificationService().scheduleNotification(
                  id: 999,
                  title: '🔔 Debug Test Notification',
                  body: 'This is a debug-mode-only test notification.',
                  hour: testHour,
                  minute: testMinute,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Test notification scheduled at $testHour:${testMinute.toString().padLeft(2, '0')}'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('📢 Schedule Test Notification (in 1 minute)'),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await NotificationService().resetDailyReminderFlag();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Daily Reminder Flag Reset')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('🔄 Reset Daily Reminder Flag'),
            ),
          ],
        ),
      ),
    );
  }
}
