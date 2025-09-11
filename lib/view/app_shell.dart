import 'package:flutter/material.dart';
import 'package:myapp/features/bottomnavigation.dart';
import 'package:myapp/features/step_tracker.dart';
import 'package:myapp/view/homepage.dart';
import 'package:myapp/view/profilepage.dart';
import 'package:myapp/view/rewardshistory.dart';
import 'package:myapp/view/rewardspage.dart';
import 'package:provider/provider.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    HomePage(
      stepGaugeKey: _stepGaugeKey,
      dailyStreakKey: _dailyStreakKey,
      pointsEarnedKey: _pointsEarnedKey,
      mockStepsKey: _mockStepsKey,
    ),
    const RewardsPage(),
    const RewardHistoryPage(),
    const ProfilePageContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // You can access your StepTracker and other providers here
    final stepTracker = Provider.of<StepTracker>(context);

    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
