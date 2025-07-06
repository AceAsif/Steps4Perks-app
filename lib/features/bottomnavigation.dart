import 'package:flutter/material.dart';
import 'package:myapp/view/homepage.dart'; // To use homepage.dart file code
import 'package:myapp/view/rewardspage.dart'; // To use rewardspage.dart file code
import 'package:myapp/view/activitypage.dart'; // To use activitypage.dart file code
import 'package:myapp/view/profilepage.dart'; // To use profilepage.dart file code
import 'package:myapp/features/step_tracker.dart';
import 'package:provider/provider.dart';

class Bottomnavigation extends StatefulWidget {
  const Bottomnavigation({super.key, required this.title});

  final String title;

  @override
  State<Bottomnavigation> createState() => _BottomnavigationState();
}

class _BottomnavigationState extends State<Bottomnavigation> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomePageContent(),
    ActivityPage(),
    RewardsPage(),
    ProfilePageContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          children: [
            // 🔝 Custom Top Bar with Notification Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bell Icon with Badge
                  IconButton(
                    icon: _buildNotificationIcon(context),
                    onPressed: () {
                      Provider.of<StepTracker>(context, listen: false).clearNewDayFlag();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications cleared')),
                      );
                    },
                  ),

                  // Centered Title
                  Expanded(
                    child: Center(
                      child: Text(
                        'Hello Asif',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Profile Icon
                  GestureDetector(
                    onTap: () {
                      // Optional: Navigate to profile
                    },
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundImage: AssetImage('assets/profile.png'),
                    ),
                  ),
                ],
              ),
            ),

            // 🔻 Page Content (Selected Tab)
            Expanded(
              child: _widgetOptions.elementAt(_selectedIndex),
            ),

            // 🔻 Bottom Navigation Bar
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
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
                      currentIndex: _selectedIndex,
                      selectedItemColor: Colors.deepPurple,
                      unselectedItemColor: Colors.grey,
                      onTap: _onItemTapped,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the notification icon with badge.
  Widget _buildNotificationIcon(BuildContext context) {
    final stepTracker = Provider.of<StepTracker>(context);
    return Stack(
      children: [
        const Icon(Icons.notifications, size: 28),
        if (stepTracker.isNewDay)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
