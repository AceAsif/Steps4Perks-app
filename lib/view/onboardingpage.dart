import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  void _onDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const Bottomnavigation(title: 'Steps4Perks'),
        ),
      );
    }
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
                  if (_currentPage < 2) // Only show the 'Next' button on the first two pages
                    const SizedBox(width: 80), // Placeholder to balance the Next button
                  if (_currentPage == 2)
                    const SizedBox(width: 80), // Placeholder to balance the Next button

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) => _buildPageIndicator(index)),
                  ),
                  if (_currentPage < 2)
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
                  if (_currentPage == 2)
                    TextButton(
                      onPressed: _onDone,
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
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

  void _onContinue(BuildContext context, bool enableNotifications) async {
    if (enableNotifications) {
      final granted = await NotificationService().requestNotificationPermissions();
      if (granted) {
        await _scheduleDailyNotifications();
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const Bottomnavigation(title: 'Steps4Perks'),
        ),
      );
    }
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
