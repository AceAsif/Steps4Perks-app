import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Required for openAppSettings()

/// Displays a dialog informing the user how to disable notifications.
/// Allows for customization of the dialog text if needed.
Future<void> showDisableNotificationDialog(
  BuildContext context, {
  String title = "Disable Notifications",
  String description = "To fully stop notifications, please disable them in your phone's app settings for Steps4Perks.",
  String cancelText = "Cancel",
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
