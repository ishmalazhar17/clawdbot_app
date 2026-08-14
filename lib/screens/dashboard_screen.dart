// =====================================================================
// dashboard_screen.dart — the "home" tab. Shows today's reminders,
// upcoming tasks, and recent notes at a glance.
//
// TODAY'S STATUS: placeholder UI with sample text. Real data from the
// database gets wired in on Aug 16 per the plan.
// =====================================================================

import 'package:flutter/material.dart';

// StatelessWidget = a screen that doesn't need to redraw itself when
// data changes internally (we'll switch to StatefulWidget once this
// screen actually loads live data from the database).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(
        child: Text(
          'Today\'s reminders and notes will show here.\n(Real data coming Aug 16)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}