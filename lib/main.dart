import 'package:flutter/material.dart';
import 'homepage.dart'; // To use homepage.dart file code
import 'rewardspage.dart'; // To use rewardspage.dart file code

void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Steps4Perks',
      debugShowCheckedModeBanner: false, //This removes the debug sign
      theme: ThemeData(
        //I added the Tea Green colour because it looks Calming and Neutral
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFD0F0C0)),
      ),
      home: const MyHomePage(title: 'Steps4Perks'),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
        type: BottomNavigationBarType.fixed, // This helps to fix the more than 3 items disappering issue.
        items: const <BottomNavigationBarItem>[
          
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
        
        selectedItemColor: Colors.deepPurple, // You can change this color
        
        onTap: _onItemTapped,
        backgroundColor: Color(0xFFD0F0C0),
      ),
    );
  }
}

