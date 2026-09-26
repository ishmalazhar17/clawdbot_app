// =====================================================================
// auth_service.dart — handles talking to the backend's /auth/signup
// and /auth/login endpoints, and safely storing the returned login
// token on the phone using flutter_secure_storage.
//
// WHY flutter_secure_storage instead of just saving it in a normal
// variable or sqflite: this token proves who the user is on every
// future request. flutter_secure_storage uses the phone's built-in
// encrypted storage (Android Keystore) — plain sqflite or shared
// preferences are NOT encrypted and are the wrong place for a secret
// like this.
//
// NOTE: replace kBackendBaseUrl below with whatever your existing
// constant is called, if you already have one from Phase 1 — don't
// keep two different URLs floating around the project.
// =====================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// TEMPORARY — replace this with your existing Phase 1 constant once
// you tell me its name and location.
const String kBackendBaseUrl = "https://recede-nerd-sip.ngrok-free.dev";

class AuthService {
  // Singleton pattern — same idea as DBHelper in db_helper.dart, so
  // the whole app shares one AuthService instance.
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  // The secure storage box. "token" is just the key name we'll save
  // the login token under, like a labeled slot in a locked drawer.
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = "auth_token";

  // ---------------------------------------------------------------
  // SIGNUP — calls POST /auth/signup with an email + password.
  // Returns true on success, false on failure. Does NOT log the
  // user in automatically — Sep 20's Signup screen will decide
  // whether to auto-login or send them to the Login screen after.
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> signup(String email, String password) async {
    final url = Uri.parse('$kBackendBaseUrl/auth/signup');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        // The backend should send back a message explaining what
        // went wrong (e.g. "email already registered").
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['detail'] ?? 'Signup failed. Please try again.',
        };
      }
    } catch (e) {
      // This catches network failures — no internet, backend down,
      // ngrok tunnel not running, etc.
      return {
        'success': false,
        'error': 'Could not reach the server. Check your connection.',
      };
    }
  }

  // ---------------------------------------------------------------
  // LOGIN — calls POST /auth/login. On success, saves the returned
  // token to secure storage so the user stays logged in.
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$kBackendBaseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final token = body['access_token'];

        if (token == null) {
          return {
            'success': false,
            'error': 'Login succeeded but no token was returned.',
          };
        }

        await _storage.write(key: _tokenKey, value: token);
        return {'success': true};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['detail'] ?? 'Incorrect email or password.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Could not reach the server. Check your connection.',
      };
    }
  }

  // ---------------------------------------------------------------
  // Reads the saved token, if any. Returns null if the user has
  // never logged in or has logged out.
  // ---------------------------------------------------------------
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // ---------------------------------------------------------------
  // Quick true/false check — used on app launch (Sep 20 task) to
  // decide whether to show the Login screen or go straight to the
  // Dashboard.
  // ---------------------------------------------------------------
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // ---------------------------------------------------------------
  // LOGOUT — deletes the saved token. The next isLoggedIn() check
  // will correctly return false.
  // ---------------------------------------------------------------
  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
  }
}