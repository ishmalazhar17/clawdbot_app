// =====================================================================
// reminders_tab.dart — Reminders section of the Memory screen.
//
// AUG 17 UPDATE: adds a search bar (filters the list as you type) and
// priority color tags (Green/Yellow/Red) shown as a colored icon next
// to each reminder, plus a priority picker in the Add form.
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
  // The FULL list, straight from the database, never filtered.
  List<Map<String, dynamic>> _allReminders = [];

  // The list actually shown on screen — either the same as
  // _allReminders, or a filtered-down version if the user is
  // searching.
  List<Map<String, dynamic>> _filteredReminders = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshReminders();

    // Runs every time the search text changes (each keystroke) and
    // re-applies the filter.
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    // Cleans up the listener/controller when this screen is closed,
    // to avoid memory leaks.
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshReminders() async {
    final data = await DBHelper.instance.getReminders();
    setState(() {
      _allReminders = data;
    });
    _applyFilter();
  }

  // Filters _allReminders down to just the ones whose task text
  // contains the search query (case-insensitive), and updates what's
  // actually shown.
  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredReminders = _allReminders;
      } else {
        _filteredReminders = _allReminders
            .where((r) => r['task'].toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _deleteReminder(int id) async {
    await DBHelper.instance.deleteReminder(id);
    _refreshReminders();
  }

  // Maps a priority string to an actual color for display.
  Color _priorityColor(String priority) {
    switch (priority) {
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.orange;
      case 'green':
      default:
        return Colors.green;
    }
  }

  void _showAddReminderDialog() {
    final taskController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    String selectedPriority = 'green'; // default selection

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder lets this dialog have its OWN small bit of
        // changeable state (the selected priority) without needing to
        // rebuild the whole RemindersTab screen behind it.
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  const SizedBox(height: 12),
                  // A row of 3 selectable colored chips for priority.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _priorityChip('green', 'Low', selectedPriority, (value) {
                        setDialogState(() => selectedPriority = value);
                      }),
                      _priorityChip('yellow', 'Medium', selectedPriority, (value) {
                        setDialogState(() => selectedPriority = value);
                      }),
                      _priorityChip('red', 'High', selectedPriority, (value) {
                        setDialogState(() => selectedPriority = value);
                      }),
                    ],
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

                    final id = await DBHelper.instance.insertReminder({
                      'task': taskController.text.trim(),
                      'date': dateController.text.trim(),
                      'time': timeController.text.trim(),
                      'priority': selectedPriority,
                      'completed': 0,
                    });

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
      },
    );
  }

  // A single small colored selectable chip, used 3 times above for
  // green/yellow/red priority selection.
  Widget _priorityChip(
    String value,
    String label,
    String currentSelection,
    void Function(String) onSelect,
  ) {
    final isSelected = currentSelection == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: _priorityColor(value),
            radius: isSelected ? 18 : 14, // slightly bigger when selected
            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search bar, pinned at the top of the screen.
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search reminders...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                // A small "x" button to clear the search, only shown
                // when there's actually text to clear.
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          // Expanded makes the list take up all remaining vertical
          // space below the search bar.
          Expanded(
            child: _filteredReminders.isEmpty
                ? const Center(child: Text('No reminders found.'))
                : ListView.builder(
                    itemCount: _filteredReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _filteredReminders[index];
                      return ListTile(
                        // A small colored dot showing this reminder's
                        // priority level.
                        leading: CircleAvatar(
                          backgroundColor: _priorityColor(reminder['priority'] ?? 'green'),
                          radius: 8,
                        ),
                        title: Text(reminder['task']),
                        subtitle: Text('${reminder['date']} at ${reminder['time']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteReminder(reminder['id']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}