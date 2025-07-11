import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // REQUIRED for SystemUiOverlayStyle
import 'package:myapp/services/notification_service.dart'; // Import your NotificationService

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
  Widget build(BuildContext context) {
    // Prevent access to debug tools if not in debug mode (release or profile mode)
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
      // --- FIX: Set a solid background color for the Scaffold ---
      backgroundColor: Colors.grey[900], // A dark background for the entire page
      appBar: AppBar(
        title: const Text(
          '🐞 Debug Tools',
          style: TextStyle(color: Colors.white), // Explicitly set title color to white
        ),
        backgroundColor: Colors.deepOrange, // A distinct color for debug page's AppBar
        iconTheme: const IconThemeData(color: Colors.white), // Ensure back button/other icons are white
        // --- System UI Overlay Style for this dark AppBar and page ---
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light, // For Android: Light icons (white)
          statusBarBrightness: Brightness.dark,     // For iOS: Light text (white)
          statusBarColor: Colors.deepOrange,        // Match AppBar color for a solid look behind status bar
        ),
      ),
      body: SingleChildScrollView( // Use SingleChildScrollView for scrollability
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07, vertical: screenHeight * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Notification Testing Section ---
            _buildSectionTitle('Notification Testing'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final now = DateTime.now();
                final testMinute = (now.minute + 1) % 60;
                final nextHour = now.hour + (now.minute + 1) ~/ 60;

                await NotificationService().scheduleNotification(
                  id: 999, // Unique ID for test notification
                  title: '🔔 Debug Test Notification',
                  body: 'This is a debug-mode-only test notification.',
                  hour: nextHour,
                  minute: testMinute,
                );

                if (context.mounted) {
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

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Daily Reminder Flag Reset'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text('🔄 Reset Daily Reminder Flag'),
            ),

            const SizedBox(height: 40),

            // --- Main Thread Performance Testing Section ---
            _buildSectionTitle('Main Thread Performance'),
            const SizedBox(height: 20),
            Text(
              'Synchronous Task Time: $_syncTaskTime',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), // Text color for dark background
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), // Text color for dark background
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

            // --- Guidance for Performance Analysis ---
            _buildSectionTitle('Performance Guidance'),
            const SizedBox(height: 10),
            const Text(
              'If your app feels slow or "janky" (stutters), it means the UI thread is overloaded.',
              style: TextStyle(fontSize: 14, color: Colors.white70), // Adjusted for dark background
            ),
            const SizedBox(height: 10),
            const Text(
              'Look for "Skipped frames!" warnings in your console. For deep analysis, use:',
              style: TextStyle(fontSize: 14, color: Colors.white70), // Adjusted for dark background
            ),
            const SizedBox(height: 5),
            const Text(
              '1. Flutter DevTools (Performance Tab & CPU Profiler)\n2. `showPerformanceOverlay: true` in MaterialApp',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), // Adjusted for dark background
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method for consistent section titles
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

  /// Simulates a blocking synchronous task on the main thread.
  /// This will cause UI jank if it runs for too long.
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
      SnackBar(content: Text('Synchronous task completed in ${stopwatch.elapsedMilliseconds} ms')),
    );
  }

  /// Simulates an asynchronous, non-blocking task.
  /// This will not cause UI jank as it yields control to the event loop.
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
      SnackBar(content: Text('Asynchronous task completed in ${stopwatch.elapsedMilliseconds} ms')),
    );
  }
}
