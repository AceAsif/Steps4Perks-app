import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED for SystemUiOverlayStyle
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// A dedicated page for debugging and testing various app functionalities.
/// Only accessible when the app is running in debug mode.
class DebugToolsPage extends StatefulWidget {
  const DebugToolsPage({super.key});

  @override
  State<DebugToolsPage> createState() => _DebugToolsPageState();
}

class _DebugToolsPageState extends State<DebugToolsPage> {
  String _syncTaskTime = 'N/A'; // To display time taken by synchronous task
  String _asyncTaskTime = 'N/A'; // To display time taken by asynchronous task

  @override
  void initState() {
    super.initState();
    // It's good practice to initialize timezone data once in the app.
    // If it's not already done, you can do it here for testing.
    tz.initializeTimeZones();
  }

  /// Sends a test notification immediately.
  Future<void> _sendImmediateNotification() async {
    await NotificationService().showImmediateNotification();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Immediate test notification sent!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Schedules a test notification to appear 2 minutes from the current time.
  Future<void> _testScheduledNotifications() async {
    await NotificationService().cancelAllNotifications();

    final nowLocal = DateTime.now().toLocal();
    final twoMinutesLater = nowLocal.add(const Duration(minutes: 2));

    await NotificationService().scheduleNotification(
      id: 3,
      title: '⏰ Scheduled Test Notification',
      body: 'This notification is a test and should appear in 2 minutes!',
      hour: twoMinutesLater.hour,
      minute: twoMinutesLater.minute,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('✅ Scheduled Test Notification for ${twoMinutesLater.hour}:${twoMinutesLater.minute} (Local)');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Test notification scheduled for ${twoMinutesLater.hour.toString().padLeft(2, '0')}:${twoMinutesLater.minute.toString().padLeft(2, '0')}.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Checks and logs all currently pending notifications.
  Future<void> _checkPendingNotifications() async {
    final List<PendingNotificationRequest> pending =
    await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
    debugPrint('⏳ Found ${pending.length} pending notifications:');
    for (var p in pending) {
      debugPrint('   - ID: ${p.id}, Title: ${p.title}, Body: ${p.body}, Payload: ${p.payload}');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('👀 Found ${pending.length} pending notifications.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(
          child: Text(
            '🚫 Debug Tools Only Available in Debug Mode',
            style: TextStyle(fontSize: 16, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          '🐞 Debug Tools',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          statusBarColor: Colors.deepOrange,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.07,
          vertical: screenHeight * 0.04,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Notification Testing'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sendImmediateNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('🚀 Send Immediate Notification'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _testScheduledNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('⏰ Test Scheduled Notifications (in 2 min)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _checkPendingNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('👀 Check Pending Notifications'),
            ),

            const SizedBox(height: 40),

            _buildSectionTitle('Step Tracker Debug'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Provider.of<StepTracker>(context, listen: false).resetSteps();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Steps reset to 0'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('🔄 Reset Step Count (Local Only)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Confirm Reset'),
                      content: const Text(
                        'Are you sure you want to delete all daily step records?\nThis action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );

                if (shouldDelete == true) {
                  await DatabaseService().deleteAllDailyStats();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ All step records reset!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('🗑️ Reset All Daily Stats (Firestore)'),
            ),

            const SizedBox(height: 40),

            _buildSectionTitle('Main Thread Performance'),
            const SizedBox(height: 20),
            Text(
              'Synchronous Task Time: $_syncTaskTime',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _runSynchronousTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('⚠️ Run Blocking Sync Task (500ms)'),
            ),
            const SizedBox(height: 20),
            Text(
              'Asynchronous Task Time: $_asyncTaskTime',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _runAsyncTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('✅ Run Non-Blocking Async Task (500ms)'),
            ),
            const SizedBox(height: 40),

            _buildSectionTitle('Performance Guidance'),
            const SizedBox(height: 10),
            const Text(
              'If your app feels slow or "janky" (stutters), it means the UI thread is overloaded.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            const Text(
              'Look for "Skipped frames!" warnings in your console. For deep analysis, use:',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 5),
            const Text(
              '1. Flutter DevTools (Performance Tab & CPU Profiler)\n2. `showPerformanceOverlay: true` in MaterialApp',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40, thickness: 2, color: Colors.grey),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Colors.grey),
      ],
    );
  }

  void _runSynchronousTask() {
    final stopwatch = Stopwatch()..start();
    debugPrint('Synchronous task started...');
    for (int i = 0; i < 500000000; i++) {}
    stopwatch.stop();
    debugPrint('Synchronous task finished in ${stopwatch.elapsedMilliseconds} ms');
    if (!mounted) return;
    setState(() {
      _syncTaskTime = '${stopwatch.elapsedMilliseconds} ms';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Synchronous task completed in ${stopwatch.elapsedMilliseconds} ms'),
      ),
    );
  }

  Future<void> _runAsyncTask() async {
    final stopwatch = Stopwatch()..start();
    debugPrint('Asynchronous task started...');
    await Future.delayed(const Duration(milliseconds: 500));
    stopwatch.stop();
    debugPrint('Asynchronous task finished in ${stopwatch.elapsedMilliseconds} ms');
    if (!mounted) return;
    setState(() {
      _asyncTaskTime = '${stopwatch.elapsedMilliseconds} ms';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Asynchronous task completed in ${stopwatch.elapsedMilliseconds} ms'),
      ),
    );
  }
}