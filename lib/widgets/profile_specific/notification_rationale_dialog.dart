import 'package:flutter/material.dart';

/// Displays a reusable dialog explaining why notifications are needed.
/// Returns true if user accepts, false otherwise.
Future<bool?> showNotificationRationaleDialog(BuildContext context, {
  String title = "Stay on Track!",
  String description = "Allow Steps4Perks to send you daily reminders to walk and alerts when your rewards are ready. This helps you earn more and stay fit!",
  String declineText = "Not now",
  String acceptText = "Sounds good!",
}) async {
  return showDialog<bool>(
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
              declineText,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(
              acceptText,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
}
