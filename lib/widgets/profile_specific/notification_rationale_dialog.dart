import 'package:flutter/material.dart';

/// Displays a custom dialog explaining the benefits of enabling notifications
/// before the system's permission prompt is shown.
/// Returns true if the user accepts the rationale, false otherwise.
Future<bool?> showNotificationRationaleDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Stay on Track!", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        content: Text(
            "Allow Steps4Perks to send you daily reminders to walk and alerts when your rewards are ready. This helps you earn more and stay fit!",
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: <Widget>[
          TextButton(
            child: Text("Not now", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            onPressed: () {
              Navigator.of(context).pop(false); // User declined your rationale
            },
          ),
          TextButton(
            child: Text("Sounds good!", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            onPressed: () {
              Navigator.of(context).pop(true); // User accepts your rationale, proceed to system prompt
            },
          ),
        ],
      );
    },
  );
}
