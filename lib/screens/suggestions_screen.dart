// =====================================================================
// suggestions_screen.dart — shows proactive, color-coded suggestions
// based on the user's own usage patterns.
//
// TODAY'S STATUS: placeholder UI. Real suggestions from Person A's
// /suggestions endpoint get wired in on Aug 23.
// =====================================================================

import 'package:flutter/material.dart';

class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestions')),
      body: const Center(
        child: Text(
          'Proactive suggestions will show here.\n(Coming Aug 23)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}