import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/features/step_tracker.dart'; 
import 'package:myapp/theme/app_theme.dart'; // Import your custom theme

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => StepTracker(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Apply your custom theme
      home: const Bottomnavigation(title: 'Steps4Perks'),
    );
  }
}
