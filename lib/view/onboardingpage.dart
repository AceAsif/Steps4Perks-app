import 'package:flutter/material.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// 🟢 ADDED: Import for DatabaseService
import 'package:myapp/services/database_service.dart';
// 🟢 NOTE: These timezone imports aren't used in this file, but are harmless
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: const [
              OnboardingScreen(
                title: 'Welcome to Steps4Perks',
                description: 'Your journey to a healthier lifestyle starts here!',
                image: Icons.directions_walk,
              ),
              OnboardingScreen(
                title: 'Walk daily to earn rewards',
                description: 'Earn points for every step and redeem them for amazing perks.',
                image: Icons.card_giftcard,
              ),
              // 🟢 NOTE: This page now handles all "finish" logic
              NotificationOnboardingScreen(),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Use Opacity to keep the dot indicators centered
                  Opacity(
                    opacity: 0.0,
                    child: TextButton(onPressed: null, child: Text(_currentPage == 0 ? '' : 'Back')),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => _buildPageIndicator(index)),
                  ),
                  if (_currentPage < 2) // Only show "Next" on first two pages
                    TextButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.ease,
                        );
                      },
                      child: Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  // 🟢 REMOVED: The "Done" button is no longer here.
                  // This prevents two "done" buttons on the last page.
                  if (_currentPage == 2)
                    SizedBox(width: 80), // Placeholder to keep dots centered
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 5.0),
      height: 8.0,
      width: _currentPage == index ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: _currentPage == index ? Theme.of(context).colorScheme.primary : Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData image;

  const OnboardingScreen({
    super.key,
    required this.title,
    required this.description,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(image, size: 100, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class NotificationOnboardingScreen extends StatelessWidget {
  const NotificationOnboardingScreen({super.key});

  Future<void> _scheduleDailyNotifications() async {
    final notificationService = NotificationService();
    // ... (scheduling logic is unchanged) ...
    await notificationService.scheduleNotification(
      id: 1,
      title: '☀️ Morning Motivation',
      body: 'Start your day right! Go for a short walk and earn some perks.',
      hour: 9,
      minute: 0,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    await notificationService.scheduleNotification(
      id: 2,
      title: '🍽️ Lunchtime Steps',
      body: 'Take a break and get a few steps in before you get back to work!',
      hour: 13,
      minute: 0,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    await notificationService.scheduleNotification(
      id: 3,
      title: '🌙 Night Walk Reminder',
      body: 'Time to go for a night walk and relax!',
      hour: 18,
      minute: 0,
      scheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // 🟢 REFACTORED: This is the main fix
  void _onContinue(BuildContext context, bool enableNotifications) async {
    // Show a loading dialog so the user knows something is happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    // 1. Handle notification logic
    if (enableNotifications) {
      final granted = await NotificationService().requestNotificationPermissions();
      if (granted) {
        await _scheduleDailyNotifications();
      }
    }

    // 2. Update the 'onboardingComplete' flag in Firestore
    // We use DatabaseService for this, not SharedPreferences
    await DatabaseService().completeOnboarding();

    // 3. DO NOT NAVIGATE!
    // The StreamBuilder in AuthGate (main.dart) will detect the change
    // in Firestore and automatically switch the page to Bottomnavigation.
    // The loading dialog will disappear when the widget tree changes.
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active, size: 100, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text(
            'Stay Motivated with Notifications',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'We can send you daily reminders to help you reach your goals and earn rewards.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _onContinue(context, true),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Enable Notifications'),
          ),
          TextButton(
            onPressed: () => _onContinue(context, false),
            child: Text(
              'No thanks, skip for now',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}