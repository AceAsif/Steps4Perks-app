import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Required for openAppSettings()

/// Displays a dialog informing the user that notification permissions are needed
/// and guides them to the system settings to enable them.
void showNotificationSettingsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Notification Permissions Needed", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
            "It looks like notifications are blocked. Please enable them in your app settings to receive important reminders and reward alerts.",
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: <Widget>[
          TextButton(
            child: Text("Later", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text("Go to Settings", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
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
