import 'package:flutter/material.dart';
import 'package:myapp/view/homepage.dart';
import 'package:myapp/view/rewardspage.dart';
import 'package:myapp/view/activitypage.dart';
import 'package:myapp/view/profilepage.dart';
import 'package:myapp/widgets/custom_top_bar.dart';

/// Main Bottom Navigation Scaffold that controls all main pages
class Bottomnavigation extends StatefulWidget {
  const Bottomnavigation({super.key, required this.title});

  final String title;

  @override
  State<Bottomnavigation> createState() => _BottomnavigationState();
}

class _BottomnavigationState extends State<Bottomnavigation> {
  int _selectedIndex = 0; // Tracks the currently selected tab

  /// List of all pages in the app
  static final List<Widget> _pages = [
    const HomePageContent(),
    const ActivityPage(),
    const RewardsPage(),
    const ProfilePageContent(),
  ];

  /// Called when a tab is selected from BottomNavigationBar
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Determines if the custom top bar should be shown (hides on Profile Page)
  bool get _shouldShowTopBar => _selectedIndex != 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows content behind AppBar for modern effect
      body: SafeArea(
        child: Column(
          children: [
            // Show Top Bar on all tabs except Profile Page
            if (_shouldShowTopBar) const CustomTopBar(),

            // Main Page Content (depends on selected tab)
            Expanded(
              child: _pages[_selectedIndex],
            ),

            // Custom Bottom Navigation Bar
            _buildBottomNavigationBar(context),
          ],
        ),
      ),
    );
  }

  /// Builds the bottom navigation bar with rounded design
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16, // Safe space for devices with gesture nav
          left: 16,
          right: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30.0),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30.0),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.deepPurple,
              unselectedItemColor: Colors.grey,
              onTap: _onItemTapped,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.directions_run),
                  label: 'Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.card_giftcard),
                  label: 'Rewards',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
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
