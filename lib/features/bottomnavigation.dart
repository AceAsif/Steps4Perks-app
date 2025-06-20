import 'package:flutter/material.dart';
import 'package:myapp/view/homepage.dart'; // To use homepage.dart file code
import 'package:myapp/view/rewardspage.dart'; // To use rewardspage.dart file code

class Bottomnavigation extends StatefulWidget {
  const Bottomnavigation({super.key, required this.title});

  final String title;

  @override
  State<Bottomnavigation> createState() => _BottomnavigationState();
}

class _BottomnavigationState extends State<Bottomnavigation> {
  int _selectedIndex = 0;

  //This part of the code is only for the content of the page
  static const List<Widget> _widgetOptions = <Widget>[
    // Home page content
    HomePageContent(), // This is the content for the Home page. This connects the 'Home' item of the bottom navigation bar to the HomePageContent widget.
    // Activity page content
    Center(child: Text('Activity Page', style: TextStyle(fontSize: 30))),
    // Rewards page content
    RewardsPage(),
    //Center(child: Text('Rewards Page', style: TextStyle(fontSize: 30))),
    // Profile page content
    Center(child: Text('Profile Page', style: TextStyle(fontSize: 30))),
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
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type:
            BottomNavigationBarType
                .fixed, // This helps to fix the more than 3 items disappering issue.
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Activity',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),

          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],

        currentIndex: _selectedIndex,

        selectedItemColor: Colors.deepPurple, // You can change this color

        onTap: _onItemTapped,
        backgroundColor: Color(0xFFD0F0C0),
      ),
    );
  }
}
