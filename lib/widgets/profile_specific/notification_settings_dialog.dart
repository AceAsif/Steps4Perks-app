import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Required for openAppSettings()

/// Displays a dialog guiding the user to app settings to enable permissions.
/// You can reuse this dialog for other settings too by changing the parameters.
Future<void> showNotificationSettingsDialog(
  BuildContext context, {
  String title = "Notification Permissions Needed",
  String description = "It looks like notifications are blocked. Please enable them in your app settings to receive important reminders and reward alerts.",
  String cancelText = "Later",
  String settingsText = "Go to Settings",
}) async {
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      final theme = Theme.of(context);
      return AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Semantics(
          header: true,
          child: Text(
            title,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
        ),
        content: Semantics(
          child: Text(
            description,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        actions: <Widget>[
          TextButton(
            child: Text(
              cancelText,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(
              settingsText,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings(); // Opens the app's settings screen
            },
          ),
        ],
      );
    },
  );
}
