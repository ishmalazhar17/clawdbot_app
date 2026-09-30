// =====================================================================
// dashboard_screen.dart — the "home" tab. Shows today's reminders,
// upcoming reminders, and recent notes at a glance.
//
// UPDATED Aug 24: added a gear icon in the AppBar that opens the new
// Settings screen.
//
// UPDATED Sep 30: added a "Sync Now" button in the AppBar. Pulls the
// latest data from the server (via CloudSyncService) and replaces
// the local copy, so this phone catches up with anything that
// happened on the server while it was offline or on another device.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../cloud_sync_service.dart';
import 'settings_screen.dart';

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
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final allReminders = await DBHelper.instance.getReminders();
    final allNotes = await DBHelper.instance.getNotes();

    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // UPDATED Aug 27: excludes completed reminders from both
    // sections - once you've checked something off, it shouldn't
    // keep cluttering your daily overview.
    final todayList = allReminders
        .where((r) => r['date'] == todayString && r['completed'] != 1)
        .toList();

    final upcomingList = allReminders
        .where((r) =>
            r['date'] != null &&
            r['date'].toString().compareTo(todayString) > 0 &&
            r['completed'] != 1)
        .toList();

    upcomingList.sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

    setState(() {
      _todayReminders = todayList;
      _upcomingReminders = upcomingList;
      _recentNotes = allNotes.take(3).toList();
      _loading = false;
    });
  }

  // ---- NEW TODAY: pulls the latest data from the server ----
  Future<void> _handleSyncNow() async {
    setState(() {
      _syncing = true;
    });

    final success = await CloudSyncService.instance.syncNow();

    if (!mounted) return;

    setState(() {
      _syncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Synced! Your data is up to date.'
              : 'Could not reach the server. Check your connection.',
        ),
      ),
    );

    if (success) {
      await _loadDashboardData();
    }
  }

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
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // ---- NEW TODAY: Sync Now button ----
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync Now',
            onPressed: _syncing ? null : _handleSyncNow,
          ),
          // ---- NEW TODAY: gear icon that opens Settings ----
          // Navigator.push adds a new screen ON TOP of the current
          // one (with a back arrow to return), unlike the bottom nav
          // tabs which SWAP the current screen entirely. This is the
          // right choice for a screen you visit occasionally, like
          // Settings, rather than one of your core daily tabs.
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}