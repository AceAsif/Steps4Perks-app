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
              padding: const EdgeInsets.only(bottom: 20.0), // Adjust bottom padding as needed
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20.0), // Margin from left and right edges
                decoration: BoxDecoration(
                  color: const Color(0xFFD0F0C0), // Background color of the floating bar
                  borderRadius: BorderRadius.circular(30.0), // Rounded corners
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1), // Equivalent to black with 10% opacity
                      spreadRadius: 2, // How much the shadow spreads
                      blurRadius: 10, // How blurry the shadow is
                      offset: const Offset(0, 5), // Offset of the shadow
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30.0), // Clip content to rounded corners
                  child: BottomNavigationBar(
                    // Important: Set background color to transparent to see the Container's color
                    backgroundColor: Colors.transparent,
                    elevation: 0, // No shadow from the BottomNavigationBar itself
                    type: BottomNavigationBarType.fixed, // Fixed type for more than 3 items
                    items: const <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                          icon: Icon(Icons.home), label: 'Home'),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.directions_run),
                        label: 'Activity',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.card_giftcard),
                        label: 'Rewards',
                      ),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.person), label: 'Profile'),
                    ],
                    currentIndex: _selectedIndex,
                    selectedItemColor: Colors.deepPurple,
                    unselectedItemColor: Colors.grey[700], // Adjust unselected color for visibility
                    onTap: _onItemTapped,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // No bottomNavigationBar property here anymore
    );
  }
}