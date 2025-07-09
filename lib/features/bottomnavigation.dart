import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:myapp/view/homepage.dart';
import 'package:myapp/view/activitypage.dart';
import 'package:myapp/view/rewardspage.dart';
import 'package:myapp/view/profilepage.dart';
import 'package:myapp/widgets/custom_top_bar.dart';

/// Main Scaffold with bottom navigation and top bar (if applicable)
class Bottomnavigation extends StatefulWidget {
  const Bottomnavigation({super.key, required this.title});
  final String title;

  @override
  State<Bottomnavigation> createState() => _BottomnavigationState();
}

class _BottomnavigationState extends State<Bottomnavigation> {
  int _selectedIndex = 0;

  /// List of main app pages (one per tab)
  static final List<Widget> _pages = [
    const HomePageContent(),
    const ActivityPage(),
    const RewardsPage(),
    const ProfilePageContent(),
  ];

  /// Handle tab switching
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Hide top bar on Profile page
  bool get _shouldShowTopBar => _selectedIndex != 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar:
          true, // Allows content behind AppBar for modern effect
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (_shouldShowTopBar) const CustomTopBar(),
            // const SafeArea(bottom: false, child: CustomTopBar()),
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      ),

      bottomNavigationBar: _buildBlurredNavigationBar(),
    );
  }

  /// Creates a blurred, transparent, modern-looking bottom navigation bar
  Widget _buildBlurredNavigationBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          color: Colors.white.withOpacity(0.05), // Transparent background

          child: SafeArea(
            top: false, // Prevent padding from top

            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.deepPurple,
              unselectedItemColor: Colors.grey,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.directions_run_outlined),
                  activeIcon: Icon(Icons.directions_run),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard_outlined),
                  activeIcon: Icon(Icons.card_giftcard),
                  label: 'Rewards',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
