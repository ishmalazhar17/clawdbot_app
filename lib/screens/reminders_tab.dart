// =====================================================================
// reminders_tab.dart — the Reminders section of the Memory screen.
// Add, view, and delete reminders. Same code as before, just moved
// into its own file so Memory can hold multiple tabs.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../notification_helper.dart';

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    _refreshReminders();
  }

  Future<void> _refreshReminders() async {
    final data = await DBHelper.instance.getReminders();
    setState(() {
      _reminders = data;
    });
  }

  Future<void> _deleteReminder(int id) async {
    await DBHelper.instance.deleteReminder(id);
    _refreshReminders();
  }

  void _showAddReminderDialog() {
    final taskController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: 'Task'),
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                  hintText: '2026-08-20',
                ),
              ),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Time (HH:MM)',
                  hintText: '18:00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
                       ElevatedButton(
              onPressed: () async {
                if (taskController.text.trim().isEmpty) return;

                // Insert the reminder and get back its auto-generated
                // database id — we need this id to link the
                // notification to this specific reminder.
                final id = await DBHelper.instance.insertReminder({
                  'task': taskController.text.trim(),
                  'date': dateController.text.trim(),
                  'time': timeController.text.trim(),
                  'priority': 'green',
                  'completed': 0,
                });

                // Try to parse the date/time text into a real
                // DateTime, and schedule a notification for it.
                // Wrapped in try/catch since the user might type an
                // invalid date/time format (real parsing from natural
                // language comes later — for now this expects the
                // exact YYYY-MM-DD and HH:MM formats from the hints).
                try {
                  final dateParts = dateController.text.trim().split('-');
                  final timeParts = timeController.text.trim().split(':');

                  final scheduledDate = DateTime(
                    int.parse(dateParts[0]),
                    int.parse(dateParts[1]),
                    int.parse(dateParts[2]),
                    int.parse(timeParts[0]),
                    int.parse(timeParts[1]),
                  );

                  await NotificationHelper.instance.scheduleNotification(
                    id: id,
                    title: 'Clawd Bot Reminder',
                    body: taskController.text.trim(),
                    scheduledDate: scheduledDate,
                  );
                  } catch (e) {
                  // ignore: avoid_print
                  print('Notification scheduling failed: $e');
                }

                Navigator.pop(context);
                _refreshReminders();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        child: const Icon(Icons.add),
      ),
      body: _reminders.isEmpty
          ? const Center(child: Text('No reminders yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(reminder['task']),
                  subtitle: Text('${reminder['date']} at ${reminder['time']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteReminder(reminder['id']),
                  ),
                );
              },
            ),
    );
  }
}