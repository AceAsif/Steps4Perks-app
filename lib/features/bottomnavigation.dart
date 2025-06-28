import 'package:flutter/material.dart';
import 'package:myapp/view/homepage.dart'; // To use homepage.dart file code
import 'package:myapp/view/rewardspage.dart'; // To use rewardspage.dart file code
import 'package:myapp/view/activitypage.dart'; // To use activitypage.dart file code
import 'package:myapp/view/profilepage.dart'; // To use profilepage.dart file code

class Bottomnavigation extends StatefulWidget {
  const Bottomnavigation({super.key, required this.title});

  final String title;

  @override
  State<Bottomnavigation> createState() => _BottomnavigationState();
}

class _BottomnavigationState extends State<Bottomnavigation> {
  int _selectedIndex = 0;

  // This part of the code is only for the content of the page
  static const List<Widget> _widgetOptions = <Widget>[
    // Home page content
    HomePageContent(), // This is the content for the Home page. This connects the 'Home' item of the bottom 
    // Activity page content
    ActivityPage(),
    // Rewards page content
    RewardsPage(),
    // Profile page content
    ProfilePageContent(),
    // Assuming ProfilePage also has a widget, replacing Center for consistency
    // If ProfilePage is just a placeholder, you can keep Center or create a simple ProfilePageWidget
    // For demonstration, let's assume it's ProfilePage() or a similar widget.
    // If you don't have a ProfilePage widget yet, you can use:
    //Center(child: Text('Profile Page', style: TextStyle(fontSize: 30))),
    // Example: ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      // Use Stack to place the page content and the floating navigation bar
      body: Stack(
        children: [
          // This is the main content area of the selected page
          _widgetOptions.elementAt(_selectedIndex),

          // This positions the floating navigation bar at the bottom center
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16, // dynamic bottom safe area + spacing
                left: 16,
                right: 16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFD0F0C0),
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1), // Equivalent to black with 10% opacity
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
                    items: const <BottomNavigationBarItem>[
                      BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                      BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Activity'),
                      BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
                      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                    ],
                    currentIndex: _selectedIndex,
                    selectedItemColor: Colors.deepPurple,
                    unselectedItemColor: Colors.grey[700],
                    onTap: _onItemTapped,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      // No bottomNavigationBar property here anymore
    );
  }
}