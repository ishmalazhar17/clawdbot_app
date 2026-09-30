// =====================================================================
// cloud_sync_service.dart — talks to Person A's backend endpoints for
// Reminders, Notes, and Object Locations (the ones built Sep 25-26).
//
// This mirrors the same pattern as auth_service.dart: every call
// attaches the saved login token as a Bearer token, so the backend
// knows which user's data it's reading/writing.
//
// This file does NOT change your local database (db_helper.dart) —
// it only handles talking to the server. Wiring these calls into the
// actual UI screens (so adding a reminder also pushes it to the
// cloud) is a separate step we'll do after this file is confirmed
// working.
// =====================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

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