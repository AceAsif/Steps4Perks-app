import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:steps4perks/features/step_tracker.dart';
import 'package:steps4perks/features/profile_image_provider.dart';
import 'package:steps4perks/services/database_service.dart';
import 'package:steps4perks/view/debug_tools_page.dart';

class CustomTopBar extends StatefulWidget {
  const CustomTopBar({super.key});

  @override
  State<CustomTopBar> createState() => _CustomTopBarState();
}

class _CustomTopBarState extends State<CustomTopBar> {
  int _tapCount = 0;
  String _name = "Asif"; // Default fallback

  final List<String> _avatarOptions = [
    'assets/profile.png',
    'assets/female.png',
    'assets/run.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final profile = await DatabaseService().getUserProfile();
    if (mounted) {
      setState(() {
        if (profile != null && profile['name'] != null) {
          _name = profile['name'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 Watch ProfileImageProvider for automatic updates
    final imageProvider = context.watch<ProfileImageProvider>();
    final profileImagePath = _avatarOptions[imageProvider.selectedImageIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🔔 Notification icon with badge
          IconButton(
            icon: _buildNotificationIcon(context),
            onPressed: () {
              Provider.of<StepTracker>(context, listen: false).clearNewDayFlag();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications cleared')),
              );
            },
          ),

          // 👋 Hello Name
          Expanded(
            child: Center(
              child: Text(
                'Hello $_name',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),

          // 🧑 Profile image - READ ONLY, tap for debug access
          GestureDetector(
            onTap: () {
              // 🟢 CHANGED: Only use for debug access (5 taps)
              // Profile picture editing is now ONLY in ProfilePage
              _tapCount++;
              // 🟢 FIX: Debug tools (mock steps, data wipe) must never be
              // reachable in release builds — that would let users fake
              // steps and farm reward points.
              if (_tapCount >= 5 && kDebugMode) {
                _tapCount = 0;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugToolsPage()),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🐞 Debug Tools Unlocked')),
                );
              } else if (_tapCount == 1) {
                // 🟢 Hint: Guide user to profile page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('💡 Go to Profile page to change your picture'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(profileImagePath),
            ),
          ),
        ],
      ),
    );
  }

  /// 📌 Notification icon with red badge
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

// 🟢 REMOVED: _showProfileImagePicker method
// Profile picture editing is now ONLY available in ProfilePage
}
