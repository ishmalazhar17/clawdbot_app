// =====================================================================
// memory_screen.dart — the Memory tab's shell. Now holds all 3 tabs:
// Reminders, Notes, and Locations.
// =====================================================================

import 'package:flutter/material.dart';
import 'reminders_tab.dart';
import 'notes_tab.dart';
import 'locations_tab.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Memory'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reminders'),
              Tab(text: 'Notes'),
              Tab(text: 'Locations'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RemindersTab(),
            NotesTab(),
            LocationsTab(),
          ],
        ),
      ),
    );
  }
}