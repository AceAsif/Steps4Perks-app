import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';

class CustomTopBar extends StatelessWidget {
  const CustomTopBar({super.key});

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

          // Profile Icon
          GestureDetector(
            onTap: () {
              // Optional: Navigate to profile page
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
