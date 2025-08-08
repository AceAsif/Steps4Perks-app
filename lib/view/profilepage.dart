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

  Future<void> _testScheduledNotifications() async {
    final notificationService = NotificationService();

    final acceptedRationale = await showNotificationRationaleDialog(context);
    if (acceptedRationale == true) {
      final granted = await notificationService.requestNotificationPermissions();
      await _checkNotificationStatus();

      if (granted) {
        await notificationService.cancelAllNotifications();

        final nowLocal = DateTime.now().toLocal();
        debugPrint('🌎 Current Local Time: $nowLocal');

        // Schedule the first test notification for 2 minutes from now.
        final firstTestTime = nowLocal.add(const Duration(minutes: 2));
        await notificationService.scheduleNotification(
          id: 3,
          title: '⏰ First Test Notification',
          body: 'This should fire in 2 minutes!',
          hour: firstTestTime.hour,
          minute: firstTestTime.minute,
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('✅ Scheduled First Test Notification for ${firstTestTime.hour}:${firstTestTime.minute} (Local)');

        // Schedule the second test notification for 5 minutes after the first one.
        final secondTestTime = firstTestTime.add(const Duration(minutes: 3));
        await notificationService.scheduleNotification(
          id: 4,
          title: '🌙 Night Walk Reminder',
          body: 'Time to go for a night walk and relax!',
          hour: secondTestTime.hour,
          minute: secondTestTime.minute,
          scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        debugPrint('✅ Scheduled Night Walk Notification for ${secondTestTime.hour}:${secondTestTime.minute} (Local)');
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission not granted.')),
          );
        }
      }
    }
  }

  Future<void> _toggleNotifications(bool newValue) async {
    final notificationService = NotificationService();
    if (newValue) {
      final accepted = await showNotificationRationaleDialog(context);
      if (accepted == true) {
        final granted = await notificationService.requestNotificationPermissions();
        await _checkNotificationStatus();

        if (granted) {
          // You can add logic to re-schedule notifications here if needed
        }
      } else {
        setState(() => _notificationsEnabled = false);
      }
    } else {
      await notificationService.cancelAllNotifications();
      if (context.mounted) {
        showDisableNotificationDialog(context);
      }
    }
  }

  Future<void> _checkPendingNotifications() async {
    final List<PendingNotificationRequest> pending =
    await FlutterLocalNotificationsPlugin().pendingNotificationRequests();
    debugPrint('⏳ Found ${pending.length} pending notifications:');
    for (var p in pending) {
      debugPrint('   - ID: ${p.id}, Title: ${p.title}, Body: ${p.body}, Payload: ${p.payload}');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found ${pending.length} pending notifications.')),
      );
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

            SizedBox(height: screenHeight * 0.02),
            ElevatedButton(
              onPressed: _testScheduledNotifications,
              child: const Text('⏰ Test Scheduled Notifications'),
            ),
            SizedBox(height: screenHeight * 0.02),
            ElevatedButton(
              onPressed: _checkPendingNotifications,
              child: const Text('👀 Check Pending Notifications'),
            ),

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

            ElevatedButton(
              onPressed: () async {
                await NotificationService().showImmediateNotification();
                debugPrint('Immediate test notification sent.');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Immediate test notification sent!'),
                    ),
                  );
                }
              },
              child: const Text('🚀 Send Immediate Notification'),
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