// =====================================================================
// dashboard_screen.dart — the "home" tab. Shows today's reminders.
//
// AUG 14 UPDATE: this now actually reads from and writes to the real
// local database (db_helper.dart), instead of showing fake text.
// This proves the database chain works end-to-end: insert -> read ->
// display on screen.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';

// Changed from StatelessWidget to StatefulWidget because this screen
// now needs to hold data (the list of reminders) that can change
// while the app is running.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Holds the list of reminders fetched from the database. Starts
  // empty until we load real data.
  List<Map<String, dynamic>> _reminders = [];

  // initState() runs ONCE, automatically, the moment this screen is
  // first created — a good place to kick off loading data.
  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  // Fetches all reminders from the database and, if there aren't any
  // yet (first time running the app), inserts one test reminder so
  // you have something to see and verify the database actually works.
  Future<void> _loadReminders() async {
    final existing = await DBHelper.instance.getReminders();

    if (existing.isEmpty) {
      // No reminders yet — insert a test one so we can SEE that
      // writing to the database works.
      await DBHelper.instance.insertReminder({
        'task': 'Test reminder from Aug 14 setup',
        'date': '2026-08-15',
        'time': '09:00',
        'priority': 'green',
        'completed': 0,
      });
    }

    // Fetch again (now guaranteed to have at least one row) and
    // update the screen to show it.
    final reminders = await DBHelper.instance.getReminders();

    // setState() tells Flutter "the data changed, please redraw."
    setState(() {
      _reminders = reminders;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _reminders.isEmpty
          // Shown briefly while the database is still loading.
          ? const Center(child: CircularProgressIndicator())
          // ListView.builder efficiently displays a scrollable list —
          // one row per reminder in _reminders.
          : ListView.builder(
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(reminder['task']),
                  subtitle: Text('${reminder['date']} at ${reminder['time']}'),
                );
              },
            ),
    );
  }
}