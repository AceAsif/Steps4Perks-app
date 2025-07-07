import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/widgets/profile_specific/options_tile.dart';
import 'package:myapp/widgets/profile_specific/notification_rationale_dialog.dart';
import 'package:myapp/widgets/profile_specific/disable_notification_dialog.dart';
import 'package:myapp/widgets/profile_specific/notification_settings_dialog.dart';

class ProfilePageContent extends StatefulWidget {
  const ProfilePageContent({super.key});

  @override
  State<ProfilePageContent> createState() => _ProfilePageContentState();
}

class _ProfilePageContentState extends State<ProfilePageContent> {
  bool _notificationsEnabled = false;
  bool _isPermissionPermanentlyDenied = false;
  late AndroidDeviceInfo _androidInfo;

  @override
  void initState() {
    super.initState();
    _initializeAndCheckPermissions();
  }

  Future<void> _initializeAndCheckPermissions() async {
    if (Platform.isAndroid) {
      _androidInfo = await DeviceInfoPlugin().androidInfo;
    }
    await _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = (_androidInfo.version.sdkInt >= 33)
          ? await Permission.notification.status
          : PermissionStatus.granted;
    } else if (Platform.isIOS) {
      status = await Permission.notification.status;
    } else {
      status = PermissionStatus.denied;
    }

    if (!mounted) return; // ✅ Fixes async BuildContext warning
    setState(() {
      _notificationsEnabled = status.isGranted;
      _isPermissionPermanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
    });
  }

  Future<void> _toggleNotifications(bool newValue) async {
    if (newValue) {
      final accepted = await showNotificationRationaleDialog(context);
      if (accepted == true) {
        final granted = await NotificationService().requestNotificationPermissions();
        if (granted) {
          debugPrint("✅ Notifications enabled.");
          await _checkNotificationStatus();
          await NotificationService().scheduleDailyReminderOnce(hour: 10, minute: 0);
        } else {
          debugPrint("❌ Notifications denied.");
          await _checkNotificationStatus();
        }
      } else {
        if (!mounted) return;
        setState(() => _notificationsEnabled = false);
      }
    } else {
      showDisableNotificationDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bodyTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07, vertical: screenHeight * 0.04),
        child: Column(
          children: [
            // Profile Header
            CircleAvatar(
              radius: screenWidth * 0.12,
              backgroundImage: const AssetImage('assets/profile.png'),
            ),
            SizedBox(height: screenHeight * 0.02),
            Text('Asif',
                style: TextStyle(fontSize: screenWidth * 0.06, fontWeight: FontWeight.bold, color: bodyTextColor)),
            Text('asif@gmail.com', style: TextStyle(fontSize: screenWidth * 0.045, color: subtitleColor)),
            SizedBox(height: screenHeight * 0.04),

            _buildSectionTitle('App Settings', bodyTextColor),
            OptionTile(
              icon: Icons.notifications,
              label: 'Enable Notifications',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              onTap: () => _toggleNotifications(!_notificationsEnabled),
            ),
            if (!_notificationsEnabled && _isPermissionPermanentlyDenied)
              _buildBlockedNotificationButton(screenHeight, screenWidth),

            SizedBox(height: screenHeight * 0.04),
            _buildSectionTitle('General', bodyTextColor),
            OptionTile(icon: Icons.star, label: 'Referral Boosters', onTap: () {}),
            OptionTile(icon: Icons.mail_outline, label: 'Contact Support', onTap: () {}),
            OptionTile(icon: Icons.info_outline, label: 'About Steps4Perks', onTap: () {}),
            SizedBox(height: screenHeight * 0.025),

            // Logout & Reminder Buttons (Modern Look + Safe Spacing)
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 24, // Space above nav bar
                top: 24, // Space above reminder button
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Add logout logic here
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Log Out'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null && mounted) {
                        await NotificationService().scheduleNotification(
                          id: 999,
                          title: '🔔 Custom Reminder',
                          body: 'It’s time for your custom walk!',
                          hour: time.hour,
                          minute: time.minute,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Reminder set for ${time.format(context)}')),
                        );
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: const Text("Set Custom Reminder"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color? color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildBlockedNotificationButton(double screenHeight, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(top: screenHeight * 0.02),
      child: ElevatedButton(
        onPressed: () => showNotificationSettingsDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015, horizontal: screenWidth * 0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          "Notifications Blocked? Fix in App Settings",
          style: TextStyle(fontSize: screenWidth * 0.04),
        ),
      ),
    );
  }
}
