import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/view/debug_tools_page.dart'; // ✅ Import Debug Tools Page

class CustomTopBar extends StatefulWidget {
  const CustomTopBar({super.key});

  @override
  State<CustomTopBar> createState() => _CustomTopBarState();
}

class _CustomTopBarState extends State<CustomTopBar> {
  int _tapCount = 0; // ✅ Tap counter for hidden access

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Notification Icon with Badge
          IconButton(
            icon: _buildNotificationIcon(context),
            onPressed: () {
              Provider.of<StepTracker>(context, listen: false).clearNewDayFlag();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications cleared')),
              );
            },
          ),

          // Centered Title
          const Expanded(
            child: Center(
              child: Text(
                'Hello Asif',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // Profile Icon with Hidden Debug Access
          GestureDetector(
            onTap: () {
              _tapCount++;
              if (_tapCount >= 5) {
                _tapCount = 0; // reset after navigation
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugToolsPage()),
                );
                // ✅ Snackbar after entering Debug Tools
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🐞 Debug Tools Unlocked')),
                );
              }
            },
            child: const CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage('assets/profile.png'),
            ),
          ),
        ],
      ),
    );
  }

  /// Notification icon with red badge if it's a new day.
  static Widget _buildNotificationIcon(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    return Stack(
      children: [
        const Icon(Icons.notifications, size: 28),
        if (stepTracker.isNewDay)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
