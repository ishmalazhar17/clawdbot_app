// =====================================================================
// dashboard_screen.dart — the "home" tab. Shows today's reminders,
// upcoming reminders, and recent notes at a glance.
//
// AUG 16 UPDATE: replaces the simple full-list view with organized
// sections, filtered and sorted by date.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _todayReminders = [];
  List<Map<String, dynamic>> _upcomingReminders = [];
  List<Map<String, dynamic>> _recentNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Fetches reminders and notes, then sorts them into the sections
  // this screen displays.
  Future<void> _loadDashboardData() async {
    final allReminders = await DBHelper.instance.getReminders();
    final allNotes = await DBHelper.instance.getNotes();

    // Today's date as a string in the same YYYY-MM-DD format the
    // reminders use, so we can compare them directly as text.
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Split reminders into "today" (date matches exactly) and
    // "upcoming" (date is any string that sorts after today's date —
    // simple text comparison works here since YYYY-MM-DD format sorts
    // correctly as plain text).
    final todayList = allReminders
        .where((r) => r['date'] == todayString)
        .toList();

    final upcomingList = allReminders
        .where((r) => r['date'] != null && r['date'].toString().compareTo(todayString) > 0)
        .toList();

    // Sort upcoming reminders so the soonest date shows first.
    upcomingList.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

    setState(() {
      _todayReminders = todayList;
      _upcomingReminders = upcomingList;
      // Only show the 3 most recent notes (they're already sorted
      // newest-first by db_helper.dart's "ORDER BY id DESC").
      _recentNotes = allNotes.take(3).toList();
      _loading = false;
    });
  }

  // A small reusable header widget used above each section.
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          // RefreshIndicator adds "pull down to refresh" behavior —
          // standard on most mobile apps.
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                children: [
                  _sectionHeader("Today's Reminders"),
                  if (_todayReminders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Nothing due today.'),
                    )
                  else
                    ..._todayReminders.map((r) => ListTile(
                          leading: const Icon(Icons.notifications_active, color: Colors.green),
                          title: Text(r['task']),
                          subtitle: Text('at ${r['time']}'),
                        )),

                  _sectionHeader('Upcoming Reminders'),
                  if (_upcomingReminders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No upcoming reminders.'),
                    )
                  else
                    ..._upcomingReminders.take(5).map((r) => ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text(r['task']),
                          subtitle: Text('${r['date']} at ${r['time']}'),
                        )),

                  _sectionHeader('Recent Notes'),
                  if (_recentNotes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('No notes yet.'),
                    )
                  else
                    ..._recentNotes.map((n) => ListTile(
                          leading: const Icon(Icons.note),
                          title: Text(n['title']),
                          subtitle: Text(
                            n['content'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis, // adds "..." if text is too long
                          ),
                        )),

                  // A bit of empty space at the bottom so the last
                  // item isn't crowded against the screen edge.
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}