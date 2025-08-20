import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:myapp/widgets/profile_specific/options_tile.dart';
import 'package:myapp/widgets/profile_specific/notification_rationale_dialog.dart';
import 'package:myapp/widgets/profile_specific/disable_notification_dialog.dart';
import 'package:myapp/widgets/profile_specific/notification_settings_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
    } else {
      status = PermissionStatus.denied;
    }

    setState(() {
      _notificationsEnabled = status.isGranted;
      _isPermissionPermanentlyDenied =
          status.isPermanentlyDenied || status.isRestricted;
    });
  }

  /// Schedules three daily notifications for morning, lunch, and evening.
  Future<void> _scheduleDailyNotifications() async {
    final notificationService = NotificationService();
    // Cancel all previous notifications before scheduling new ones
    await notificationService.cancelAllNotifications();

    // Schedule the morning notification
    await notificationService.scheduleNotification(
      id: 1,
      title: '☀️ Morning Motivation',
      body: 'Start your day right! Go for a short walk and earn some perks.',
      hour: 9,
      minute: 0,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    // Schedule the lunch notification
    await notificationService.scheduleNotification(
      id: 2,
      title: '🍽️ Lunchtime Steps',
      body: 'Take a break and get a few steps in before you get back to work!',
      hour: 13,
      minute: 0,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    // Schedule the evening notification
    await notificationService.scheduleNotification(
      id: 3,
      title: '🌙 Night Walk Reminder',
      body: 'Time to go for a night walk and relax!',
      hour: 18,
      minute: 0,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _toggleNotifications(bool newValue) async {
    final notificationService = NotificationService();
    if (newValue) {
      final accepted = await showNotificationRationaleDialog(context);
      if (accepted == true) {
        final granted = await notificationService.requestNotificationPermissions();
        await _checkNotificationStatus();

        if (granted) {
          // Schedule the new notifications when permission is granted
          await _scheduleDailyNotifications();
        }
      } else {
        setState(() => _notificationsEnabled = false);
      }
    } else {
      // Cancel all notifications when the user turns them off
      await notificationService.cancelAllNotifications();
      if (context.mounted) {
        showDisableNotificationDialog(context);
      }
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
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.07,
          vertical: screenHeight * 0.04,
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: screenWidth * 0.12,
              backgroundImage: const AssetImage('assets/profile.png'),
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'Asif',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
                fontWeight: FontWeight.bold,
                color: bodyTextColor,
              ),
            ),
            Text(
              'asif@gmail.com',
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                color: subtitleColor,
              ),
            ),
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

            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.015,
                  horizontal: screenWidth * 0.05,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Log Out',
                style: TextStyle(fontSize: screenWidth * 0.045),
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedNotificationButton(
      double screenHeight, double screenWidth) {
    return Padding(
      padding: EdgeInsets.only(top: screenHeight * 0.02),
      child: ElevatedButton(
        onPressed: () => showNotificationSettingsDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: screenHeight * 0.015,
            horizontal: screenWidth * 0.04,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          "Notifications Blocked? Fix in App Settings",
          style: TextStyle(fontSize: screenWidth * 0.04),
        ),
      ),
    );
  }
}
