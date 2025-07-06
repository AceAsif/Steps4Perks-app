import 'package:flutter/material.dart';
import 'package:myapp/view/homepage.dart'; // To use homepage.dart file code
import 'package:myapp/view/rewardspage.dart'; // To use rewardspage.dart file code
import 'package:myapp/view/activitypage.dart'; // To use activitypage.dart file code
import 'package:myapp/view/profilepage.dart'; // To use profilepage.dart file code
import 'package:myapp/widgets/custom_top_bar.dart';

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
            const CustomTopBar(),

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
}
