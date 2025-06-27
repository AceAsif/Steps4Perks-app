import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/features/step_tracker.dart'; 

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD0F0C0)),
        //In Flutter, the useMaterial3 property is a flag in ThemeData 
        //that enables the use of Material Design 3 (also known as Material You) styling in your app.
        useMaterial3: true,
      ),
      home: const Bottomnavigation(title: 'Steps4Perks'),
    );
  }
}
