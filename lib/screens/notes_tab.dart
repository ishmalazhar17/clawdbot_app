// =====================================================================
// notes_tab.dart — the Notes section of the Memory screen.
// Same pattern as reminders_tab.dart: add, view, delete.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _refreshNotes();
  }

  Future<void> _refreshNotes() async {
    final data = await DBHelper.instance.getNotes();
    setState(() {
      _notes = data;
    });
  }

  Future<void> _deleteNote(int id) async {
    await DBHelper.instance.deleteNote(id);
    _refreshNotes();
  }

  void _showAddNoteDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3, // lets this field grow to 3 lines tall
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
                if (titleController.text.trim().isEmpty) return;

                await DBHelper.instance.insertNote({
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'created_at': DateTime.now().toIso8601String(),
                });

                Navigator.pop(context);
                _refreshNotes();
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
        onPressed: _showAddNoteDialog,
        child: const Icon(Icons.add),
      ),
      body: _notes.isEmpty
          ? const Center(child: Text('No notes yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return ListTile(
                  leading: const Icon(Icons.note),
                  title: Text(note['title']),
                  subtitle: Text(note['content'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteNote(note['id']),
                  ),
                );
              },
            ),
    );
  }
}