import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/profile_image_service.dart';
import 'package:myapp/view/debug_tools_page.dart';

class CustomTopBar extends StatefulWidget {
  const CustomTopBar({super.key});

  @override
  State<CustomTopBar> createState() => _CustomTopBarState();
}

class _CustomTopBarState extends State<CustomTopBar> {
  int _tapCount = 0;
  String _name = "Asif"; // Default fallback
  String _profileImagePath = 'assets/profile.png'; // Default avatar

  final List<String> avatarOptions = [
    'assets/profile.png',
    'assets/female.png',
    'assets/run.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profile = await DatabaseService().getUserProfile();
    final imagePath = await ProfileImageService.getSelectedImage();

    if (mounted) {
      setState(() {
        if (profile != null && profile['name'] != null) {
          _name = profile['name'];
        }
        _profileImagePath = imagePath;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

          // 🧑 Profile image with tap-to-change and debug access
          GestureDetector(
            onTap: () {
              _tapCount++;
              if (_tapCount >= 5) {
                _tapCount = 0;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugToolsPage()),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🐞 Debug Tools Unlocked')),
                );
              } else {
                _showProfileImagePicker(context);
              }
            },
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(_profileImagePath),
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

  /// 🖼️ Modal to pick new profile image
  void _showProfileImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Your Avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                children: avatarOptions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final path = entry.value;

                  return GestureDetector(
                    onTap: () async {
                      await ProfileImageService.saveSelectedImageIndex(index);
                      if (!mounted) return;
                      setState(() => _profileImagePath = path);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Profile image updated!')),
                      );
                    },
                    child: CircleAvatar(
                      backgroundImage: AssetImage(path),
                      radius: 28,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
