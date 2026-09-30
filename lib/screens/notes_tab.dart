// =====================================================================
// notes_tab.dart — Notes section of the Memory screen.
//
// AUG 17 UPDATE: adds a search bar that filters by title or content.
//
// UPDATED Sep 30 (local DB): records a "last_modified" timestamp.
//
// UPDATED Sep 30 (cloud sync): "Add Note" and "Delete" try to push/
// remove the same note on the server.
//
// UPDATED Sep 30 (offline retry queue): a new note gets a temporary
// negative id and stays marked "unsynced" until it's actually pushed;
// deleting a server-known note that can't be deleted right now (e.g.
// offline) gets queued in pending_deletes, and the next "Sync Now"
// retries it automatically.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../cloud_sync_service.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  List<Map<String, dynamic>> _allNotes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshNotes();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotes() async {
    final data = await DBHelper.instance.getNotes();
    setState(() {
      _allNotes = data;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = _allNotes;
      } else {
        _filteredNotes = _allNotes.where((n) {
          final title = n['title'].toString().toLowerCase();
          final content = (n['content'] ?? '').toString().toLowerCase();
          return title.contains(query) || content.contains(query);
        }).toList();
      }
    });
  }

  // ---------------------------------------------------------------
  // If this note never made it to the server (negative id), there's
  // nothing to delete remotely - just remove it locally. If it's a
  // real server-known note (positive id), try to delete it on the
  // server now; if that fails (offline), queue it in pending_deletes
  // so a future Sync Now retries the delete.
  // ---------------------------------------------------------------
  Future<void> _deleteNote(int id) async {
    await DBHelper.instance.deleteNote(id);

    if (id > 0) {
      final result = await CloudSyncService.instance.deleteNote(id);
      if (!result['success']) {
        await DBHelper.instance.addPendingDelete('notes', id);
      }
    }

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
                maxLines: 3,
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

                final now = DateTime.now().toIso8601String();

                // Temporary negative id - means "server doesn't know
                // about this yet."
                final tempId = DBHelper.instance.generateTempId();

                final newNote = {
                  'id': tempId,
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'created_at': now,
                  'last_modified': now,
                  'synced': 0,
                };

                await DBHelper.instance.insertNote(newNote);

                // Try to push it right now. If it succeeds (we're
                // online), swap the local row over to the server's
                // real id immediately. If it fails (offline), it
                // just stays queued with its negative id until the
                // next Sync Now.
                final pushResult = await CloudSyncService.instance.createNote({
                  'title': newNote['title'],
                  'content': newNote['content'],
                  'created_at': newNote['created_at'],
                });

                if (pushResult['success']) {
                  final serverData = pushResult['data'];
                  await DBHelper.instance.replaceNoteId(tempId, {
                    'id': serverData['id'],
                    'title': serverData['title'],
                    'content': serverData['content'],
                    'created_at': serverData['created_at'],
                    'last_modified': serverData['last_modified'],
                    'synced': 1,
                  });
                }

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notes...',
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
            child: _filteredNotes.isEmpty
                ? const Center(child: Text('No notes found.'))
                : ListView.builder(
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
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
          ),
        ],
      ),
    );
  }
}