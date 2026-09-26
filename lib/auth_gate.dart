// =====================================================================
// auth_gate.dart — decides what the user sees FIRST when the app
// opens: if they already have a saved login token, skip straight to
// the main app (HomeNavigation). If not, show the Login screen.
//
// This is a small widget that sits in front of everything else and
// makes that one decision, using a FutureBuilder to wait for the
// (fast, local) secure-storage check to finish first.
// =====================================================================

import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'screens/login_screen.dart';
import 'main.dart' show HomeNavigation;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.instance.isLoggedIn(),
      builder: (context, snapshot) {
        // Still checking secure storage — show a brief loading screen.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isLoggedIn = snapshot.data ?? false;
        return isLoggedIn ? const HomeNavigation() : const LoginScreen();
      },
    );
  }
}