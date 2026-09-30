// =====================================================================
// reminders_tab.dart — Reminders section of the Memory screen.
//
// UPDATED Aug 27: adds a category picker to the Add form, pulling
// from the categories you set up in Settings (Aug 24).
//
// UPDATED Sep 30 (local DB): both "Add" and "Edit" now record a
// "last_modified" timestamp, needed for cloud syncing.
//
// UPDATED Sep 30 (cloud sync): every Add/Edit/Delete now ALSO tries
// to push that same change to the server via CloudSyncService. If
// there's no internet or the server is unreachable, this silently
// fails and the LOCAL save still succeeds — so the app keeps working
// offline. This is a "best effort" sync for individual actions; the
// full /sync endpoint (still being built by Person A) will handle
// properly catching up everything that was missed while offline.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db_helper.dart';
import '../notification_helper.dart';
import '../cloud_sync_service.dart';
import 'settings_screen.dart';

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key});

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  List<Map<String, dynamic>> _allReminders = [];
  List<Map<String, dynamic>> _filteredReminders = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshReminders();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
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
    // Best-effort cloud delete - ignored if it fails (offline, etc).
    // ignore: unawaited_futures
    CloudSyncService.instance.deleteReminder(id);
    _refreshReminders();
  }

  // ---- NEW TODAY: marks a reminder done/not-done ----
  Future<void> _toggleCompleted(int id, bool isCurrentlyCompleted) async {
    await DBHelper.instance.updateReminderStatus(id, isCurrentlyCompleted ? 0 : 1);
    // Best-effort cloud update of just the completed status.
    // ignore: unawaited_futures
    _pushReminderUpdate(id);
    _refreshReminders();
  }

  // ---------------------------------------------------------------
  // NEW TODAY: reads a reminder's current full data from the LOCAL
  // database (by id) and pushes that complete row to the cloud. This
  // is used after any local-only update (like the checkbox toggle)
  // so the cloud version doesn't need duplicating the same fields
  // twice in two different places.
  // ---------------------------------------------------------------
  Future<void> _pushReminderUpdate(int id) async {
    final all = await DBHelper.instance.getReminders();
    final match = all.where((r) => r['id'] == id).toList();
    if (match.isEmpty) return;
    final reminder = match.first;
    await CloudSyncService.instance.updateReminder(id, {
      'task': reminder['task'],
      'date': reminder['date'],
      'time': reminder['time'],
      'priority': reminder['priority'],
      'completed': reminder['completed'],
      'category': reminder['category'],
    });
  }

  // ---- NEW (Aug 28): edit an EXISTING reminder ----
  void _showEditReminderDialog(Map<String, dynamic> reminder) async {
    final availableCategories = await _loadCategories();
    if (!mounted) return;

    final taskController = TextEditingController(text: reminder['task']);
    final dateController = TextEditingController(text: reminder['date']);
    final timeController = TextEditingController(text: reminder['time']);
    String selectedPriority = reminder['priority'] ?? 'green';
    String? selectedCategory = reminder['category'];
    final int reminderId = reminder['id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Reminder'),
              content: SingleChildScrollView(
                child: Column(
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
                      ),
                    ),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time (HH:MM)',
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    if (availableCategories.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: availableCategories.contains(selectedCategory)
                            ? selectedCategory
                            : null,
                        decoration: const InputDecoration(labelText: 'Category (optional)'),
                        items: availableCategories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedCategory = value);
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (taskController.text.trim().isEmpty) return;

                    final updatedFields = {
                      'task': taskController.text.trim(),
                      'date': dateController.text.trim(),
                      'time': timeController.text.trim(),
                      'priority': selectedPriority,
                      'category': selectedCategory,
                      'last_modified': DateTime.now().toIso8601String(),
                    };

                    await DBHelper.instance.updateReminder(reminderId, updatedFields);

                    // Best-effort cloud update - doesn't block the UI
                    // or throw if it fails (e.g. offline).
                    // ignore: unawaited_futures
                    CloudSyncService.instance.updateReminder(reminderId, {
                      'task': updatedFields['task'],
                      'date': updatedFields['date'],
                      'time': updatedFields['time'],
                      'priority': updatedFields['priority'],
                      'category': updatedFields['category'],
                      'completed': reminder['completed'] ?? 0,
                    });

                    // Cancel the OLD notification before scheduling
                    // the new one - critical, otherwise a stale
                    // notification at the old time would still fire.
                    await NotificationHelper.instance.cancelNotification(reminderId);

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
                        id: reminderId,
                        title: 'Clawd Bot Reminder',
                        body: taskController.text.trim(),
                        scheduledDate: scheduledDate,
                      );
                    } catch (e) {
                      // ignore: avoid_print
                      print('Notification re-scheduling failed: $e');
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

  Future<List<String>> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(SettingsKeys.categories) ?? [];
  }

  void _showAddReminderDialog() async {
    final availableCategories = await _loadCategories();

    final taskController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    String selectedPriority = 'green';
    String? selectedCategory;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Reminder'),
              content: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 12),
                    if (availableCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'No categories set up yet. Add some in Settings.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category (optional)'),
                        items: availableCategories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedCategory = value);
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (taskController.text.trim().isEmpty) return;

                    final newReminder = {
                      'task': taskController.text.trim(),
                      'date': dateController.text.trim(),
                      'time': timeController.text.trim(),
                      'priority': selectedPriority,
                      'completed': 0,
                      'category': selectedCategory,
                      'last_modified': DateTime.now().toIso8601String(),
                    };

                    final id = await DBHelper.instance.insertReminder(newReminder);

                    // Best-effort cloud create - doesn't block the UI
                    // or throw if it fails (e.g. offline).
                    // ignore: unawaited_futures
                    CloudSyncService.instance.createReminder(newReminder);

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
            radius: isSelected ? 18 : 14,
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search reminders...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _filteredReminders.isEmpty
                ? const Center(child: Text('No reminders found.'))
                : ListView.builder(
                    itemCount: _filteredReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _filteredReminders[index];
                      final category = reminder['category'];
                      final hasCategory = category != null && category.toString().isNotEmpty;

                      final isCompleted = reminder['completed'] == 1;

                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: isCompleted,
                              onChanged: (_) =>
                                  _toggleCompleted(reminder['id'], isCompleted),
                            ),
                            CircleAvatar(
                              backgroundColor: _priorityColor(reminder['priority'] ?? 'green'),
                              radius: 6,
                            ),
                          ],
                        ),
                        title: Text(
                          reminder['task'],
                          style: isCompleted
                              ? TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                )
                              : null,
                        ),
                        subtitle: Text(
                          hasCategory
                              ? '${reminder['date']} at ${reminder['time']} • $category'
                              : '${reminder['date']} at ${reminder['time']}',
                        ),
                        onTap: () => _showEditReminderDialog(reminder),
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