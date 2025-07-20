import 'package:flutter/material.dart';
import 'package:myapp/features/bottomnavigation.dart'; // Your main navigation

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

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
    // --- FIX: Ensure StepTracker's initialization is awaited here ---
    // Access StepTracker via Provider.
    // Its constructor calls _init() which handles permission, pedometer,
    // and crucially, loads data from DatabaseService (Firestore).
    //final stepTracker = Provider.of<StepTracker>(context, listen: false);

    // Give StepTracker time to initialize and load data, including from Firestore.
    // Since StepTracker's _init() is called in its constructor, and it already
    // listens to auth changes and loads data, we just need to ensure the data
    // has a moment to populate.
    // A simple delay or a more explicit Future in StepTracker could be used.
    // For now, let's assume StepTracker's internal streams will eventually
    // populate, and we'll add a slight delay to ensure UI is ready.

    // OPTIONAL: If StepTracker has a public Future for its full initialization, await it here.
    // Example: await stepTracker.initializationComplete; // If you added such a Future

    // Add a minimum display time for the splash screen
    await Future.delayed(const Duration(seconds: 3)); // Show splash for at least 3 seconds

    // --- Navigate to the main app UI ---
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Bottomnavigation(title: 'Steps4Perks')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Your splash screen UI
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor, // Use your app's primary color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your App Logo
            Image.asset(
              'assets/app_logo.png', // Make sure you have an app logo asset
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