import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Required for openAppSettings()

/// Displays a dialog informing the user that notifications must be disabled
/// via the phone's system settings, and provides a button to go there.
void showDisableNotificationDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Disable Notifications", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
            "To fully stop notifications, please disable them in your phone's app settings for Steps4Perks.",
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: <Widget>[
          TextButton(
            child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
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
