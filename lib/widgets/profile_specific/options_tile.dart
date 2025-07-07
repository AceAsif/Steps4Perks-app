import 'package:flutter/material.dart';

/// A reusable widget to display a single option tile, typically used in lists
/// like a profile or settings page. It provides a consistent icon, label,
/// and an optional trailing widget (like a chevron or a Switch).
class OptionTile extends StatelessWidget {
  /// The icon to display on the left side of the tile.
  final IconData icon;

  /// The main text label for the option.
  final String label;

  /// The callback function to execute when the tile is tapped.
  final VoidCallback onTap;

  /// An optional widget to display on the right side of the tile.
  /// If null, a default chevron icon will be displayed.
  final Widget? trailing;

  const OptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive sizing of elements
    final screenWidth = MediaQuery.of(context).size.width;

    // Get text color from the current theme for consistency
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Column(
      children: [
        ListTile(
          // Leading icon for the option
          leading: Icon(icon, size: screenWidth * 0.07, color: textColor),
          // Title text for the option
          title: Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w500,
              color: textColor, // Apply theme text color
            ),
          ),
          // Trailing widget, either provided or a default chevron icon
          trailing: trailing ?? Icon(Icons.chevron_right, color: textColor),
          // Callback when the tile is tapped
          onTap: onTap,
        ),
        // A divider to visually separate options in a list
        Divider(
          thickness: 1,
          // Corrected: Use withAlpha() instead of withOpacity()
          color: textColor != null ? textColor.withAlpha((255 * 0.3).round()) : Colors.grey.withAlpha((255 * 0.3).round()),
        ),
      ],
    );
  }
}
