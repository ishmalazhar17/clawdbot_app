// =====================================================================
// reminders_tab.dart — Reminders section of the Memory screen.
//
// UPDATED Aug 27: adds a category picker to the Add form, pulling
// from the categories you set up in Settings (Aug 24). This is what
// finally makes the Settings categories feature actually DO
// something - until today, you could create categories but nothing
// in the app used them.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db_helper.dart';
import '../notification_helper.dart';
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
    _refreshReminders();
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

  // ---- NEW TODAY: reads the categories saved in Settings ----
  Future<List<String>> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(SettingsKeys.categories) ?? [];
  }

  void _showAddReminderDialog() async {
    // Load the current categories BEFORE opening the dialog, so
    // they're ready immediately rather than showing a loading state
    // inside the dialog itself.
    final availableCategories = await _loadCategories();

    final taskController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    String selectedPriority = 'green';
    // Starts as null (no category selected) - completely optional,
    // since not everyone wants to categorize every reminder.
    String? selectedCategory;

    // Guard for using BuildContext after an "await" above - Flutter
    // warns about this since the widget could theoretically be gone
    // by the time _loadCategories() finishes. "mounted" confirms this
    // screen is still on-screen before we try to show a dialog on it.
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
                    // ---- NEW TODAY: the category dropdown ----
                    // If no categories exist yet, this shows a helper
                    // message instead of an empty/confusing dropdown.
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

                    final id = await DBHelper.instance.insertReminder({
                      'task': taskController.text.trim(),
                      'date': dateController.text.trim(),
                      'time': timeController.text.trim(),
                      'priority': selectedPriority,
                      'completed': 0,
                      'category': selectedCategory,
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
                      // ---- NEW TODAY: shows the category as a small
                      // subtitle line, only when one was actually set ----
                      final category = reminder['category'];
                      final hasCategory = category != null && category.toString().isNotEmpty;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _priorityColor(reminder['priority'] ?? 'green'),
                          radius: 8,
                        ),
                        title: Text(reminder['task']),
                        subtitle: Text(
                          hasCategory
                              ? '${reminder['date']} at ${reminder['time']} • $category'
                              : '${reminder['date']} at ${reminder['time']}',
                        ),
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