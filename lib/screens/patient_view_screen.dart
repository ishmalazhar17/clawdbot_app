// =====================================================================
// patient_view_screen.dart — READ-ONLY view of a linked patient's
// reminders, notes, and saved object locations (Oct 2 schedule item:
// "Caregiver Dashboard screen ... each with their own reminders view
// (read-only)").
//
// This screen is reached by tapping a patient in CaregiverScreen's
// "People You're Watching" list. There are intentionally NO edit,
// delete, or create actions anywhere here — the backend's
// /caregiver/patients/{id}/... endpoints are read-only by design, so
// this screen matches that: it's a window into someone else's data,
// not a way to change it.
// =====================================================================

import 'package:flutter/material.dart';
import '../caregiver_service.dart';

class PatientViewScreen extends StatefulWidget {
  final int patientId;
  final String patientEmail;

  const PatientViewScreen({
    super.key,
    required this.patientId,
    required this.patientEmail,
  });

  @override
  State<PatientViewScreen> createState() => _PatientViewScreenState();
}

class _PatientViewScreenState extends State<PatientViewScreen> {
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final remindersResult = await CaregiverService.instance.getPatientReminders(widget.patientId);
    final notesResult = await CaregiverService.instance.getPatientNotes(widget.patientId);
    final locationsResult = await CaregiverService.instance.getPatientObjectLocations(widget.patientId);

    if (!mounted) return;

    // A 403 here almost always means the link was removed from the
    // other side since this list was last loaded - surface that
    // plainly rather than showing an empty, confusing screen.
    if (!remindersResult['success'] || !notesResult['success'] || !locationsResult['success']) {
      setState(() {
        _error = "Couldn't load this person's data. The link may have been removed.";
        _loading = false;
      });
      return;
    }

    setState(() {
      _reminders = List<Map<String, dynamic>>.from(
        (remindersResult['data'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      _notes = List<Map<String, dynamic>>.from(
        (notesResult['data'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      _locations = List<Map<String, dynamic>>.from(
        (locationsResult['data'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.patientEmail),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reminders', icon: Icon(Icons.notifications_outlined)),
              Tab(text: 'Notes', icon: Icon(Icons.note_outlined)),
              Tab(text: 'Locations', icon: Icon(Icons.place_outlined)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPatientData,
                    child: TabBarView(
                      children: [
                        _buildRemindersTab(),
                        _buildNotesTab(),
                        _buildLocationsTab(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildRemindersTab() {
    if (_reminders.isEmpty) {
      return const Center(child: Text('No reminders.'));
    }
    return ListView.builder(
      itemCount: _reminders.length,
      itemBuilder: (context, index) {
        final r = _reminders[index];
        final completed = r['completed'] == 1;
        return ListTile(
          leading: Icon(
            completed ? Icons.check_circle : Icons.notifications_active,
            color: completed ? Colors.grey : Colors.green,
          ),
          title: Text(
            r['task'] ?? '',
            style: completed ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
          ),
          subtitle: Text('${r['date']} at ${r['time']}'),
        );
      },
    );
  }

  Widget _buildNotesTab() {
    if (_notes.isEmpty) {
      return const Center(child: Text('No notes.'));
    }
    return ListView.builder(
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final n = _notes[index];
        return ListTile(
          leading: const Icon(Icons.note_outlined),
          title: Text(n['title'] ?? ''),
          subtitle: Text(n['content'] ?? ''),
        );
      },
    );
  }

  Widget _buildLocationsTab() {
    if (_locations.isEmpty) {
      return const Center(child: Text('No saved locations.'));
    }
    return ListView.builder(
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final l = _locations[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(l['object_name'] ?? ''),
          subtitle: Text(l['location_name'] ?? 'No location name'),
        );
      },
    );
  }
}