// =====================================================================
// signup_screen.dart — the Signup screen UI.
//
// UPDATED Sep 20: calls AuthService.signup(). On success, we
// automatically log the new user in right after (same credentials)
// so they land straight in the app instead of being bounced back to
// a Login screen they'd have to fill in again — one less step for
// someone with memory difficulties, which fits this app's whole
// purpose.
//
// UPDATED Oct 3: also wipes the local SQLite cache before navigating
// to the Dashboard. The device might still have another account's
// cached data sitting in it (e.g. someone signed up for a brand-new
// account without logging out of a previous one first) — without
// this, the new account's Dashboard could briefly show that old
// data.
// =====================================================================

import 'package:flutter/material.dart';
import '../auth_service.dart';
import '../db_helper.dart';

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
  bool _isLoading = false;

  Future<void> _handleSignupPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final signupResult = await AuthService.instance.signup(email, password);

    if (!mounted) return;

    if (signupResult['success'] != true) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(signupResult['error'] ?? 'Signup failed')),
      );
      return;
    }

    // Signup worked — now log in automatically with the same
    // credentials so the user doesn't have to type them again.
    final loginResult = await AuthService.instance.login(email, password);

    if (!mounted) return;

    if (loginResult['success'] == true) {
      // NEW: wipe any leftover local data from a previous account on
      // this device before this brand-new account's (empty) Dashboard
      // loads - see db_helper.dart's clearAllLocalData() for why this
      // matters even for a fresh signup.
      await DBHelper.instance.clearAllLocalData();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _isLoading = false;
      });
      // Rare edge case: account was created but auto-login failed
      // (e.g. a network blip right after signup). Send them to the
      // Login screen to try manually rather than leaving them stuck.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created — please log in.'),
        ),
      );
      Navigator.of(context).pop();
    }
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
                  const SizedBox(height: 16),

                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isLoading ? null : _handleSignupPressed,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign Up', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
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