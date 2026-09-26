// =====================================================================
// settings_screen.dart — lets the user configure Clawd Bot: whether
// the bot speaks its replies out loud, and a simple list of reminder
// categories they can manage.
//
// HOW SETTINGS PERSISTENCE WORKS:
// We use a package called "shared_preferences" - a simple key/value
// store built into every phone, meant for small settings like this
// (not for real data like reminders, which stay in the proper SQLite
// database). Settings saved here survive app restarts, unlike a
// plain in-memory bool that resets every time the app reopens.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// These keys are used to read/write the same settings from BOTH this
// screen AND chatbot_screen.dart - keeping them as constants here
// (rather than typing the string 'voice_replies_enabled' in two
// different files) avoids typos causing the two screens to silently
// read different values.
class SettingsKeys {
  static const String voiceRepliesEnabled = 'voice_replies_enabled';
  static const String categories = 'reminder_categories';
}


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voiceRepliesEnabled = true;
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // getBool returns null if this key has never been saved before
      // (e.g. first time opening the app) - the "?? true" means
      // default to voice ON in that case.
      _voiceRepliesEnabled =
          prefs.getBool(SettingsKeys.voiceRepliesEnabled) ?? true;
      // getStringList works the same way - defaults to an empty list
      // if nothing has been saved yet.
      _categories = prefs.getStringList(SettingsKeys.categories) ?? [];
      _loading = false;
    });
  }

  Future<void> _toggleVoiceReplies(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.voiceRepliesEnabled, value);
    setState(() {
      _voiceRepliesEnabled = value;
    });
  }

  Future<void> _addCategory(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [..._categories, name.trim()];
    await prefs.setStringList(SettingsKeys.categories, updated);
    setState(() {
      _categories = updated;
    });
  }

  Future<void> _removeCategory(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = _categories.where((c) => c != name).toList();
    await prefs.setStringList(SettingsKeys.categories, updated);
    setState(() {
      _categories = updated;
    });
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'e.g. Health, Work, Family'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _addCategory(controller.text);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Voice',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Speak bot replies out loud'),
            subtitle: const Text(
              'When off, replies are shown as text only, not spoken.',
            ),
            value: _voiceRepliesEnabled,
            onChanged: _toggleVoiceReplies,
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Reminder Categories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('No categories yet. Add one below.'),
            )
          else
            ..._categories.map((category) => ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(category),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeCategory(category),
                  ),
                )),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
              onPressed: _showAddCategoryDialog,
            ),
          ),
        ],
      ),
    );
  }
}
