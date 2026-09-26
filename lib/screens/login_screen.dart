// =====================================================================
// login_screen.dart — the Login screen UI.
//
// TODAY (Sep 17) this is just the LAYOUT — text fields and a button.
// It doesn't talk to the backend yet. That wiring happens on Sep 19
// per the Phase 2 schedule, once Person A's /auth/login endpoint and
// flutter_secure_storage are both ready.
// =====================================================================

import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers let us READ whatever the user types into these boxes.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Hides/shows the password as dots vs plain text.
  bool _obscurePassword = true;

  // Placeholder for now — Sep 19 will replace this with a real call
  // to Person A's /auth/login endpoint.
  void _handleLoginPressed() {
    final email = _emailController.text;
    final password = _passwordController.text;
    // TEMPORARY: just shows what was typed, so we can confirm the
    // screen works before any backend wiring exists.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login pressed — email: $email')),
    );
  }

  @override
  void dispose() {
    // Always clean up controllers when the screen is closed, to avoid
    // memory leaks.
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

                  // ---- Email field ----
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Password field ----
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _handleLoginPressed,
                    child: const Text('Log In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  // ---- Link to Signup screen ----
                  // NOTE: this navigation will be wired up once
                  // signup_screen.dart also exists (see below).
                  TextButton(
                    onPressed: () {
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