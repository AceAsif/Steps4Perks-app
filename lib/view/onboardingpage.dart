import 'package:flutter/material.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/services/database_service.dart';

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
              // 🟢 This page handles all "finish" logic
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
                    child: TextButton(
                      onPressed: null,
                      child: Text(_currentPage == 0 ? '' : 'Back'),
                    ),
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
                  if (_currentPage == 2)
                    const SizedBox(width: 80), // Placeholder to keep dots centered
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
        color: _currentPage == index
            ? Theme.of(context).colorScheme.primary
            : Colors.grey,
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
          Icon(image,
              size: 100,
              color: Theme.of(context).colorScheme.primary),
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

class NotificationOnboardingScreen extends StatefulWidget {
  const NotificationOnboardingScreen({super.key});

  @override
  State<NotificationOnboardingScreen> createState() =>
      _NotificationOnboardingScreenState();
}

class _NotificationOnboardingScreenState
    extends State<NotificationOnboardingScreen> {
  bool _isLoading = false;

  Future<void> _scheduleDailyNotifications() async {
    try {
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

      debugPrint('✅ All notifications scheduled successfully');
    } catch (e, stack) {
      debugPrint('❌ Error scheduling notifications: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // 🟢 REFACTORED: Main fix - uses requestNotificationsWithPrompt() and handles properly
  Future<void> _onContinue(BuildContext context, bool enableNotifications) async {
    // Guard against multiple taps
    if (_isLoading) {
      debugPrint('⚠️ Already processing, ignoring duplicate tap');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Handle notification logic
      if (enableNotifications) {
        final notificationService = NotificationService();

        // 🟢 Use the new method that shows prompts
        if (mounted) {
          final granted =
          await notificationService.requestNotificationsWithPrompt(context);

          if (granted) {
            // Schedule notifications only if user granted permission
            await _scheduleDailyNotifications();
            debugPrint('✅ Notifications enabled and scheduled');
          } else {
            debugPrint('⚠️ Notifications not enabled by user');
          }
        }
      }

      // 2. Update the 'onboardingComplete' flag in Firestore
      // Do this AFTER notification logic to ensure everything is set up
      if (mounted) {
        await DatabaseService().completeOnboarding();
        debugPrint('✅ Onboarding marked as complete');
      }

      // 3. DO NOT NAVIGATE!
      // The StreamBuilder in UserPageRouter (main.dart) will detect the change
      // in Firestore and automatically switch the page to Bottomnavigation.
      debugPrint('✅ Onboarding flow complete. Waiting for UI navigation...');
    } catch (e, stack) {
      debugPrint('❌ Error in onboarding flow: $e');
      debugPrint('Stack trace: $stack');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('An error occurred. Please try again.'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // 🟢 --- THIS IS THE FIX ---
      // Always reset the loading state, whether it succeeded or failed.
      // This will un-freeze the UI.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active,
              size: 100,
              color: Theme.of(context).colorScheme.primary),
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
          // 🟢 FIXED: Disable buttons while loading
          ElevatedButton(
            onPressed: _isLoading ? null : () => _onContinue(context, true),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text('Enable Notifications'),
          ),
          // 🟢 FIXED: Disable skip button while loading
          TextButton(
            onPressed: _isLoading ? null : () => _onContinue(context, false),
            child: Text(
              'No thanks, skip for now',
              style: TextStyle(
                color: _isLoading
                    ? Colors.grey
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}