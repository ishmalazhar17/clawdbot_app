// =====================================================================
// signup_screen.dart — the Signup screen UI.
//
// Same idea as login_screen.dart: layout only today. Sep 19–20 will
// wire this to Person A's /auth/signup endpoint.
// =====================================================================

import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;

  // Placeholder — replaced with a real /auth/signup call later.
  void _handleSignupPressed() {
    final email = _emailController.text;
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Signup pressed — email: $email')),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sign up for Clawd Bot',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 16),

                  // ---- Confirm password field ----
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- Signup button ----
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _handleSignupPressed,
                    child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Already have an account? Log in'),
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