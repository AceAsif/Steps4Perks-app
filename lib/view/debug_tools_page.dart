import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/notification_service.dart';

class DebugToolsPage extends StatefulWidget {
  const DebugToolsPage({super.key});

  @override
  State<DebugToolsPage> createState() => _DebugToolsPageState();
}

class _DebugToolsPageState extends State<DebugToolsPage> {
  String _syncTaskTime = 'N/A';
  String _asyncTaskTime = 'N/A';

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
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
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07, vertical: screenHeight * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Notification Testing'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now();
                final testMinute = (now.minute + 1) % 60;
                final nextHour = now.hour + (now.minute + 1) ~/ 60;

                await NotificationService().scheduleNotification(
                  id: 999,
                  title: '🔔 Debug Test Notification',
                  body: 'This is a debug-mode-only test notification.',
                  hour: nextHour,
                  minute: testMinute,
                );

                // FIX: Add the mounted check before using context
                if (context.mounted){
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test notification scheduled at ${nextHour.toString().padLeft(2, '0')}:${testMinute.toString().padLeft(2, '0')}'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }

              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('📢 Schedule Test Notification (in 1 min)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await NotificationService().resetDailyReminderFlag();

                // FIX: Add the mounted check before using context
                if (context.mounted){
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Daily Reminder Flag Reset'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('🔄 Reset Daily Reminder Flag'),
            ),

            const SizedBox(height: 40),

            _buildSectionTitle('Main Thread Performance'),
            const SizedBox(height: 20),
            Text(
              'Synchronous Task Time: $_syncTaskTime',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _runSynchronousTask();
              },
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await _runAsyncTask();
              },
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
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              'Look for "Skipped frames!" warnings in your console. For deep analysis, use:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            const Text(
              '1. Flutter DevTools (Performance Tab & CPU Profiler)\n2. `showPerformanceOverlay: true` in MaterialApp',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const Divider(height: 20, thickness: 1, color: Colors.grey),
      ],
    );
  }

  void _runSynchronousTask() {
    final stopwatch = Stopwatch()..start();
    debugPrint('Synchronous task started...');

    for (int i = 0; i < 500000000; i++) {
      // Simulate heavy computation
    }

    stopwatch.stop();
    debugPrint('Synchronous task finished in ${stopwatch.elapsedMilliseconds} ms');
    // FIX: Add mounted check before setState and ScaffoldMessenger
    if (!mounted) return;
    setState(() {
      _syncTaskTime = '${stopwatch.elapsedMilliseconds} ms';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Synchronous task completed in ${stopwatch.elapsedMilliseconds} ms')),
    );
  }

  Future<void> _runAsyncTask() async {
    final stopwatch = Stopwatch()..start();
    debugPrint('Asynchronous task started...');

    await Future.delayed(const Duration(milliseconds: 500));

    stopwatch.stop();
    debugPrint('Asynchronous task finished in ${stopwatch.elapsedMilliseconds} ms');
    // FIX: Add mounted check before setState and ScaffoldMessenger
    if (!mounted) return;
    setState(() {
      _asyncTaskTime = '${stopwatch.elapsedMilliseconds} ms';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Asynchronous task completed in ${stopwatch.elapsedMilliseconds} ms')),
    );
  }
}
