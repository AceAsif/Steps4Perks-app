import 'package:flutter/material.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/view/onboardingpage.dart';

class SplashScreen extends StatefulWidget {
  // This parameter now receives the value from main.dart
  final bool onboardingComplete;

  const SplashScreen({super.key, required this.onboardingComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startAppInitialization();
  }

  Future<void> _startAppInitialization() async {
    // Add a minimum display time for the splash screen
    await Future.delayed(const Duration(seconds: 3));

    // --- Navigate to the main app UI ---
    if (mounted) {
      if (widget.onboardingComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Bottomnavigation(title: 'Steps4Perks')),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Your splash screen UI
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your App Logo
            Image.asset(
              'assets/app_logo.png',
              width: MediaQuery.of(context).size.width * 0.5,
            ),
            const SizedBox(height: 20),
            // Loading Indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onPrimary),
            ),
            const SizedBox(height: 20),
            Text(
              'Steps4Perks',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
