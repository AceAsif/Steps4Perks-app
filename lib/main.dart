import 'package:flutter/material.dart';
import 'package:myapp/features/bottomnavigation.dart'; // Import your new navigation widget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFD0F0C0)),
      ),
      home: const Bottomnavigation(title: 'Steps4Perks'), // Replace MyHomePage
    );
  }
}
