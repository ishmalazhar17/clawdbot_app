// =====================================================================
// memory_screen.dart — where the user manually adds/views/edits their
// reminders, notes, and object locations.
//
// TODAY'S STATUS: placeholder UI. Real CRUD forms wired to db_helper.dart
// get built on Aug 15.
// =====================================================================

import 'package:flutter/material.dart';

class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Memory')),
      body: const Center(
        child: Text(
          'Add/view reminders, notes, and object locations here.\n(Real forms coming Aug 15)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}