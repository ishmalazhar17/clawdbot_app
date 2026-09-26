// =====================================================================
// login_screen.dart — the Login screen UI.
//
// UPDATED Sep 19: now actually calls AuthService.login(), which hits
// the backend's /auth/login endpoint and saves the returned token
// using flutter_secure_storage. On success, navigates to the main
// app (HomeNavigation). On failure, shows the real error message
// from the backend instead of the old placeholder snackbar.
// =====================================================================

import 'package:flutter/material.dart';
import '../auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  // NEW: tracks whether a login request is currently in progress, so
  // we can show a spinner and disable the button (stops the user from
  // tapping Login multiple times while waiting for the server).
  bool _isLoading = false;

  Future<void> _handleLoginPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic validation BEFORE calling the backend — no point making a
    // network request for obviously-empty fields.
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.instance.login(email, password);

    // IMPORTANT: after an "await", always check "mounted" before
    // touching context/setState. If the user navigated away or the
    // widget was disposed while we were waiting on the network call,
    // this screen might not exist anymore — using its context would
    // crash the app.
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      // Login worked — go to the main app. pushReplacementNamed (not
      // pushNamed) so the user can't tap "back" and land on the
      // Login screen again after logging in.
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Login failed')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.memory, size: 64, color: Colors.deepPurple),
                  const SizedBox(height: 12),
                  const Text(
                    'Clawd Bot',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Login button ----
                  // Shows a spinner instead of text while loading, and
                  // onPressed is null (disabled) while loading.
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _handleLoginPressed,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Log In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pushNamed('/signup');
                          },
                    child: const Text("Don't have an account? Sign up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}