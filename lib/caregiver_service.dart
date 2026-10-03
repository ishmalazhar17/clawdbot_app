// =====================================================================
// caregiver_service.dart — talks to Person A's backend endpoints for
// the multi-caregiver / family view feature (Oct 1-4 schedule item).
//
// HOW THE FLOW WORKS (this is a code-share model, not email invites):
//   1. A "primary user" (the person being cared for) calls
//      generateInviteCode() and gets back a short code, valid 15 min.
//      They read it out / text it to a family member.
//   2. The caregiver calls redeemCode(code) in THEIR OWN app - this
//      creates the permanent link. From then on:
//        - myLinkedPatients() - caregiver's list of people they watch
//        - myLinkedCaregivers() - primary user's list of who's watching them
//        - unlinkCaregiver(patientId) - either side can call this to break a link
//        - getPatientReminders/Notes/ObjectLocations(patientId) - READ-ONLY
//          views of a linked patient's data (caregiver side only - the
//          backend 403s if you're not actually linked to that patient).
//
// Every call attaches the saved login token as a Bearer token, same
// pattern as cloud_sync_service.dart.
// =====================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const String kBackendBaseUrl = 'https://recede-nerd-sip.ngrok-free.dev';

class CaregiverService {
  // Singleton pattern - same idea as AuthService and CloudSyncService.
  CaregiverService._privateConstructor();
  static final CaregiverService instance = CaregiverService._privateConstructor();

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===================================================================
  // GENERATE INVITE CODE
  // Called by the PRIMARY USER (patient). Returns a 6-character code
  // and its expiry timestamp (15 minutes from now).
  // ===================================================================
  Future<Map<String, dynamic>> generateInviteCode() async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/caregiver/invite'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {
        'success': false,
        'error': jsonDecode(response.body)['detail'] ?? 'Failed to generate a code.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // REDEEM CODE
  // Called by the CAREGIVER, entering a code the primary user shared
  // with them. On success, returns the new link (including the
  // primary user's id and email).
  // ===================================================================
  Future<Map<String, dynamic>> redeemCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('$kBackendBaseUrl/caregiver/redeem'),
        headers: await _authHeaders(),
        body: jsonEncode({'code': code.trim()}),
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {
        'success': false,
        'error': jsonDecode(response.body)['detail'] ?? 'Could not redeem this code.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // MY LINKED PATIENTS
  // For a CAREGIVER - the list of primary users they currently watch.
  // ===================================================================
  Future<Map<String, dynamic>> myLinkedPatients() async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/caregiver/my_patients'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch linked patients.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // MY LINKED CAREGIVERS
  // For a PRIMARY USER - the list of caregivers currently watching them.
  // ===================================================================
  Future<Map<String, dynamic>> myLinkedCaregivers() async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/caregiver/my_caregivers'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch linked caregivers.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // UNLINK
  // Either side of a link can call this - the primary user removing a
  // caregiver, or the caregiver removing themselves from a patient.
  // ===================================================================
  Future<Map<String, dynamic>> unlink(int patientId) async {
    try {
      final response = await http.delete(
        Uri.parse('$kBackendBaseUrl/caregiver/unlink/$patientId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 204) {
        return {'success': true};
      }
      return {'success': false, 'error': 'Failed to remove this link.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  // ===================================================================
  // READ-ONLY PATIENT DATA VIEWS (caregiver side only)
  // The backend checks the logged-in caregiver is actually linked to
  // this patientId before returning anything - a 403 here means the
  // link doesn't exist (e.g. it was revoked).
  // ===================================================================
  Future<Map<String, dynamic>> getPatientReminders(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/caregiver/patients/$patientId/reminders'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch this patient\'s reminders.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> getPatientNotes(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/caregiver/patients/$patientId/notes'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch this patient\'s notes.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }

  Future<Map<String, dynamic>> getPatientObjectLocations(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$kBackendBaseUrl/caregiver/patients/$patientId/object_locations'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'error': 'Failed to fetch this patient\'s saved locations.'};
    } catch (e) {
      return {'success': false, 'error': 'Could not reach the server.'};
    }
  }
}