// =====================================================================
// cloud_sync_service.dart — talks to Person A's backend endpoints for
// Reminders, Notes, and Object Locations.
//
// Every call attaches the saved login token as a Bearer token, so the
// backend knows which user's data it's reading/writing.
//
// UPDATED Sep 30 (offline retry queue): syncNow() now pushes any
// pending local changes (created/edited/deleted while offline) up to
// the server FIRST, before pulling the server's authoritative list
// back down. This prevents an offline local change from being wiped
// out by the pull-and-replace step.
// =====================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'db_helper.dart';

const String kBackendBaseUrl = 'https://recede-nerd-sip.ngrok-free.dev';

class CloudSyncService {
  // Singleton pattern — same idea as AuthService and DBHelper.
  CloudSyncService._privateConstructor();
  static final CloudSyncService instance = CloudSyncService._privateConstructor();

  // ---------------------------------------------------------------
  // Builds the headers every request needs: JSON content type, plus
  // the Bearer token if the user is logged in.
  // ---------------------------------------------------------------
  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===================================================================
  // SYNC NOW
  //
  // 1. Pushes any pending local changes (offline creates/edits/
  //    deletes) up to the server.
  // 2. Pulls the complete, authoritative list of reminders/notes/
  //    object locations from the server and REPLACES the local copy
  //    with it.
  //
  // Returns true on success, false if it couldn't reach the server
  // for the final pull step (the caller can show a message either
  // way).
  // ===================================================================
  Future<bool> syncNow() async {
    // Step 1: upload anything the phone has that the server doesn't
    // know about yet. Best-effort - anything that still fails here
    // (e.g. still offline) just stays queued for next time.
    await pushPendingChanges();

    // Step 2: pull the server's full authoritative list.
    final remindersResult = await getReminders();
    final notesResult = await getNotes();
    final locationsResult = await getObjectLocations();

    if (!remindersResult['success'] || !notesResult['success'] || !locationsResult['success']) {
      return false;
    }

    final List<dynamic> reminders = remindersResult['data'];
    final List<dynamic> notes = notesResult['data'];
    final List<dynamic> locations = locationsResult['data'];

    await DBHelper.instance.replaceAllReminders(
      reminders.map((r) => Map<String, dynamic>.from(r)).toList(),
    );
    await DBHelper.instance.replaceAllNotes(
      notes.map((n) => Map<String, dynamic>.from(n)).toList(),
    );
    await DBHelper.instance.replaceAllObjectLocations(
      locations.map((l) => Map<String, dynamic>.from(l)).toList(),
    );

    return true;
  }

  // ===================================================================
  // PUSH PENDING CHANGES (offline retry queue)
  //
  // Looks for any local rows marked synced = 0 (created or edited
  // while offline) and any rows in pending_deletes (deleted while
  // offline), and tries to push each one to the server now. Anything
  // that still fails (e.g. still offline) is simply left as-is, to be
  // retried the next time this runs.
  // ===================================================================
  Future<void> pushPendingChanges() async {
    await _pushPendingReminders();
    await _pushPendingNotes();
    await _pushPendingObjectLocations();
  }

  Future<void> _pushPendingReminders() async {
    final unsynced = await DBHelper.instance.getUnsyncedReminders();
    for (final r in unsynced) {
      final int id = r['id'];
      final payload = {
        'task': r['task'],
        'date': r['date'],
        'time': r['time'],
        'priority': r['priority'],
        'completed': r['completed'],
        'category': r['category'],
      };

      if (id < 0) {
        // Negative id = this reminder was never created on the
        // server. Create it now, then swap the local row over to the
        // server's real id.
        final result = await createReminder(payload);
        if (result['success']) {
          final serverData = result['data'];
          await DBHelper.instance.replaceReminderId(id, {
            'id': serverData['id'],
            'task': serverData['task'],
            'date': serverData['date'],
            'time': serverData['time'],
            'priority': serverData['priority'],
            'completed': serverData['completed'],
            'category': serverData['category'],
            'last_modified': serverData['last_modified'],
            'synced': 1,
          });
        }
      } else {
        // Positive id = this reminder already exists on the server -
        // just push the edited fields.
        final result = await updateReminder(id, payload);
        if (result['success']) {
          await DBHelper.instance.markReminderSynced(id);
        }
      }
    }

    final pendingDeletes = await DBHelper.instance.getPendingDeletes('reminders');
    for (final id in pendingDeletes) {
      final result = await deleteReminder(id);
      if (result['success']) {
        await DBHelper.instance.removePendingDelete('reminders', id);
      }
    }
  }

  Future<void> _pushPendingNotes() async {
    final unsynced = await DBHelper.instance.getUnsyncedNotes();
    for (final n in unsynced) {
      final int id = n['id'];
      final payload = {
        'title': n['title'],
        'content': n['content'],
        'created_at': n['created_at'],
      };

      if (id < 0) {
        final result = await createNote(payload);
        if (result['success']) {
          final serverData = result['data'];
          await DBHelper.instance.replaceNoteId(id, {
            'id': serverData['id'],
            'title': serverData['title'],
            'content': serverData['content'],
            'created_at': serverData['created_at'],
            'last_modified': serverData['last_modified'],
            'synced': 1,
          });
        }
      } else {
        final result = await updateNote(id, payload);
        if (result['success']) {
          await DBHelper.instance.markNoteSynced(id);
        }
      }
    }

    final pendingDeletes = await DBHelper.instance.getPendingDeletes('notes');
    for (final id in pendingDeletes) {
      final result = await deleteNote(id);
      if (result['success']) {
        await DBHelper.instance.removePendingDelete('notes', id);
      }
    }
  }

  Future<void> _pushPendingObjectLocations() async {
    final unsynced = await DBHelper.instance.getUnsyncedObjectLocations();
    for (final l in unsynced) {
      final int id = l['id'];
      final payload = {
        'object_name': l['object_name'],
        'location_name': l['location_name'],
        'latitude': l['latitude'],
        'longitude': l['longitude'],
      };

      if (id < 0) {
        final result = await createObjectLocation(payload);
        if (result['success']) {
          final serverData = result['data'];
          await DBHelper.instance.replaceObjectLocationId(id, {
            'id': serverData['id'],
            'object_name': serverData['object_name'],
            'location_name': serverData['location_name'],
            'latitude': serverData['latitude'],
            'longitude': serverData['longitude'],
            'last_modified': serverData['last_modified'],
            'synced': 1,
          });
        }
      } else {
        final result = await updateObjectLocation(id, payload);
        if (result['success']) {
          await DBHelper.instance.markObjectLocationSynced(id);
        }
      }
    }

    final pendingDeletes = await DBHelper.instance.getPendingDeletes('object_locations');
    for (final id in pendingDeletes) {
      final result = await deleteObjectLocation(id);
      if (result['success']) {
        await DBHelper.instance.removePendingDelete('object_locations', id);
      }
    }
  }

  // ===================================================================
  // REMINDERS
  // ===================================================================

  Future<Map<String, dynamic>> createReminder(Map<String, dynamic> reminder) async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/reminders'),
        headers: await _authHeaders(),
        body: jsonEncode(reminder),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': jsonDecode(response.body)['detail'] ?? 'Failed to create reminder.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> getReminders() async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/reminders'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch reminders.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> updateReminder(int id, Map<String, dynamic> reminder) async {
    try {
      final response = await http.put(
        Uri.parse('$kBackendBaseUrl/reminders/$id'),
        headers: await _authHeaders(),
        body: jsonEncode(reminder),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to update reminder.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> deleteReminder(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$kBackendBaseUrl/reminders/$id'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to delete reminder.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // NOTES
  // ===================================================================

  Future<Map<String, dynamic>> createNote(Map<String, dynamic> note) async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/notes'),
        headers: await _authHeaders(),
        body: jsonEncode(note),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': jsonDecode(response.body)['detail'] ?? 'Failed to create note.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> getNotes() async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/notes'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch notes.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> updateNote(int id, Map<String, dynamic> note) async {
    try {
      final response = await http.put(
        Uri.parse('$kBackendBaseUrl/notes/$id'),
        headers: await _authHeaders(),
        body: jsonEncode(note),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to update note.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> deleteNote(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$kBackendBaseUrl/notes/$id'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to delete note.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // OBJECT LOCATIONS
  // ===================================================================

  Future<Map<String, dynamic>> createObjectLocation(Map<String, dynamic> location) async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/object_locations'),
        headers: await _authHeaders(),
        body: jsonEncode(location),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': jsonDecode(response.body)['detail'] ?? 'Failed to create location.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> getObjectLocations() async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/object_locations'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch locations.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> updateObjectLocation(int id, Map<String, dynamic> location) async {
    try {
      final response = await http.put(
        Uri.parse('$kBackendBaseUrl/object_locations/$id'),
        headers: await _authHeaders(),
        body: jsonEncode(location),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to update location.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> deleteObjectLocation(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$kBackendBaseUrl/object_locations/$id'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to delete location.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }
}