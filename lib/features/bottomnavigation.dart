import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Required for kDebugMode

// Import your main app views
import 'package:myapp/view/homepage.dart';
import 'package:myapp/view/rewardspage.dart';
import 'package:myapp/view/activitypage.dart';
import 'package:myapp/view/profilepage.dart';

// Import your custom widgets
import 'package:myapp/widgets/custom_top_bar.dart';

// Import your DebugToolsPage
import 'package:myapp/view/debug_tools_page.dart';

/// Main Bottom Navigation Scaffold that controls all main pages.
/// It dynamically includes a 'Debug' tab when the app is in debug mode.
class Bottomnavigation extends StatefulWidget {
  const Bottomnavigation({super.key, required this.title});

  final String title;

  @override
  State<Bottomnavigation> createState() => _BottomnavigationState();
}

class _BottomnavigationState extends State<Bottomnavigation> {
  int _selectedIndex = 0; // Tracks the currently selected tab index.

  // Using 'late final' to initialize these lists in initState,
  // allowing conditional addition of debug-only elements.
  late final List<Widget> _pages;
  late final List<BottomNavigationBarItem> _navBarItems;

  @override
  void initState() {
    super.initState();

    // Initialize the core list of pages
    _pages = [
      const HomePageContent(),
      const ActivityPage(),
      const RewardsPage(),
      const ProfilePageContent(),
    ];

    // Initialize the core list of navigation bar items
    _navBarItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.directions_run),
        label: 'Activity',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.card_giftcard),
        label: 'Rewards',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    // Conditionally add the DebugToolsPage and its corresponding nav bar item
    // only when the app is running in debug mode.
    if (kDebugMode) {
      _pages.add(const DebugToolsPage()); // Add the debug page to the list of pages
      _navBarItems.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.bug_report), // Use a bug icon for debug tools
          label: 'Debug', // Label for the debug tab
        ),
      );
    }
  }

  /// Callback function called when a tab is selected from the BottomNavigationBar.
  /// Updates the [_selectedIndex] and triggers a UI rebuild.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Determines if the custom top bar should be shown.
  /// It is hidden on the Profile Page and the Debug Page (if present).
  bool get _shouldShowTopBar {
    // The last tab in the _pages list is either Profile (in release) or Debug (in debug).
    // We hide the top bar for the last tab.
    return _selectedIndex != (_pages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Allows the body content to extend behind the AppBar, useful for transparent AppBars.
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          children: [
            // Conditionally show the CustomTopBar based on the selected tab.
            if (_shouldShowTopBar) const CustomTopBar(),

            // Main Page Content:
            // Using IndexedStack to preserve the state of pages when switching tabs.
            // This prevents pages from rebuilding from scratch every time you navigate away and back.
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),

            // The custom-designed Bottom Navigation Bar.
            _buildBottomNavigationBar(context),
          ],
        ),
      ),
    );
  }

  /// Builds the custom-styled bottom navigation bar with rounded design and shadow.
  Widget _buildBottomNavigationBar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          // Add padding at the bottom to account for device's system navigation gestures.
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 16,
          right: 16,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white, // Background color of the navigation bar container
            borderRadius: BorderRadius.circular(30.0), // Rounded corners for the container
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.1), // Shadow color with opacity
                spreadRadius: 2, // How much the box shadow spreads
                blurRadius: 10, // How much the box shadow blurs
                offset: const Offset(0, 5), // Offset of the shadow (x, y)
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30.0), // Clip content to rounded corners
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent, // Make the actual bar transparent to show container color
              elevation: 0, // Remove default elevation
              type: BottomNavigationBarType.fixed, // Ensures all items are visible and equally spaced
              currentIndex: _selectedIndex, // Current active tab
              selectedItemColor: Colors.deepPurple, // Color for the selected icon/label
              unselectedItemColor: Colors.grey, // Color for unselected icons/labels
              onTap: _onItemTapped, // Callback when an item is tapped
              items: _navBarItems, // Use the dynamically generated list of items
            ),
          ),
        ),
      ),
    );
  }
}
