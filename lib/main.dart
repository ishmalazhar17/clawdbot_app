// =====================================================================
// main.dart — the entry point of the whole app. This is the first
// file that runs when the app launches.
//
// This file sets up the bottom navigation bar and switches between
// your 4 screens (Dashboard, Chatbot, Memory, Suggestions) when the
// user taps each tab.
// =====================================================================

import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/suggestions_screen.dart';

// This is the very first function that runs in the whole app.
// runApp() takes a widget and makes it fill the screen.
void main() {
  runApp(const ClawdBotApp());
}

// The root widget of the app. Sets up app-wide things like the theme
// and title, then hands off to HomeNavigation for the actual content.
class ClawdBotApp extends StatelessWidget {
  const ClawdBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clawd Bot',
      debugShowCheckedModeBanner: false, // hides the little red "DEBUG" ribbon
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomeNavigation(),
    );
  }
}

// This widget manages WHICH of the 4 screens is currently showing,
// and the bottom bar used to switch between them. It needs to be a
// StatefulWidget (not Stateless) because "which tab is selected" is
// data that changes while the app is running.
class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  // Tracks which tab is currently selected. 0 = Dashboard (the first
  // tab), matching the order of the _screens list below.
  int _selectedIndex = 0;

  // The 4 actual screen widgets, in the same order as the nav bar
  // items below. index 0 here must match index 0 in the nav bar.
  final List<Widget> _screens = const [
    DashboardScreen(),
    ChatbotScreen(),
    MemoryScreen(),
    SuggestionsScreen(),
  ];

  // Runs whenever the user taps a different tab. Calling setState()
  // tells Flutter "something changed, please redraw the screen."
  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Shows whichever screen matches the currently selected tab.
      body: _screens[_selectedIndex],

      // The bottom navigation bar with 4 tabs.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed, // keeps all 4 labels visible
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Memory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb),
            label: 'Suggestions',
          ),
        ],
      ),
    );
  }
}