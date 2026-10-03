// =====================================================================
// caregiver_screen.dart — "Family & Caregivers" screen (Oct 1-4
// schedule item: multi-caregiver / family view).
//
// Every user can do BOTH of these (the backend has no separate
// "patient" vs "caregiver" account type):
//   1. INVITE a caregiver: generate a short code, share it out loud or
//      by text, and manage the list of caregivers currently watching
//      you (with the option to remove one).
//   2. LINK to a family member: enter a code someone else shared with
//      you, and manage the list of people you're watching (tap one to
//      see their reminders/notes/locations, read-only).
// =====================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../caregiver_service.dart';
import 'patient_view_screen.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});

  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  // ---- "Invite a caregiver" section state ----
  String? _generatedCode;
  DateTime? _codeExpiresAt;
  bool _generatingCode = false;
  List<Map<String, dynamic>> _myCaregivers = [];
  bool _loadingCaregivers = true;

  // ---- "Link to a family member" section state ----
  final TextEditingController _codeController = TextEditingController();
  bool _redeeming = false;
  List<Map<String, dynamic>> _myPatients = [];
  bool _loadingPatients = true;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadMyCaregivers();
    _loadMyPatients();
    // Refreshes the on-screen "expires in Xm Ys" countdown every second.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMyCaregivers() async {
    setState(() => _loadingCaregivers = true);
    final result = await CaregiverService.instance.myLinkedCaregivers();
    if (!mounted) return;
    setState(() {
      if (result['success']) {
        _myCaregivers = List<Map<String, dynamic>>.from(
          (result['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
      _loadingCaregivers = false;
    });
  }

  Future<void> _loadMyPatients() async {
    setState(() => _loadingPatients = true);
    final result = await CaregiverService.instance.myLinkedPatients();
    if (!mounted) return;
    setState(() {
      if (result['success']) {
        _myPatients = List<Map<String, dynamic>>.from(
          (result['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
      _loadingPatients = false;
    });
  }

  Future<void> _handleGenerateCode() async {
    setState(() => _generatingCode = true);
    final result = await CaregiverService.instance.generateInviteCode();
    if (!mounted) return;
    setState(() => _generatingCode = false);

    if (result['success']) {
      setState(() {
        _generatedCode = result['data']['code'];
        // Backend sends UTC time with no 'Z'/offset marker (Python's
        // datetime.isoformat() on a naive UTC datetime). DateTime.parse
        // treats a string with no timezone marker as LOCAL time, which
        // silently shifts it by your UTC offset - appending 'Z' tells
        // Dart to parse it as UTC, then .toLocal() converts it properly
        // for comparing against DateTime.now() in _countdownText().
        _codeExpiresAt = DateTime.parse('${result['data']['expires_at']}Z').toLocal();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    }
  }

  Future<void> _handleRedeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _redeeming = true);
    final result = await CaregiverService.instance.redeemCode(code);
    if (!mounted) return;
    setState(() => _redeeming = false);

    if (result['success']) {
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You're now linked to ${result['data']['patient_email']}."),
        ),
      );
      await _loadMyPatients();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    }
  }

  Future<void> _handleRemoveCaregiver(int patientId, String caregiverEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove caregiver?'),
        content: Text('$caregiverEmail will no longer be able to view your reminders, notes, or saved locations.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await CaregiverService.instance.unlink(patientId);
    if (!mounted) return;
    if (result['success']) {
      await _loadMyCaregivers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    }
  }

  Future<void> _handleRemovePatient(int patientId, String patientEmail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop watching this person?'),
        content: Text("You'll no longer be able to view $patientEmail's reminders, notes, or saved locations."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await CaregiverService.instance.unlink(patientId);
    if (!mounted) return;
    if (result['success']) {
      await _loadMyPatients();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    }
  }

  String _countdownText() {
    if (_codeExpiresAt == null) return '';
    final remaining = _codeExpiresAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired — generate a new one.';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return 'Expires in ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family & Caregivers')),
      body: ListView(
        children: [
          // =============================================================
          // SECTION 1 — Invite a caregiver (you are the primary user)
          // =============================================================
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Invite a Caregiver',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Generate a code and share it with a family member so they can view your reminders, notes, and saved locations.',
            ),
          ),
          const SizedBox(height: 12),

          if (_generatedCode != null)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SelectableText(
                      _generatedCode!,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                    const SizedBox(height: 4),
                    Text(_countdownText()),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: _generatingCode
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code),
              label: Text(_generatedCode == null ? 'Generate Invite Code' : 'Generate New Code'),
              onPressed: _generatingCode ? null : _handleGenerateCode,
            ),
          ),

          const Divider(),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Caregivers Watching You',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_loadingCaregivers)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myCaregivers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('No caregivers linked yet.'),
            )
          else
            ..._myCaregivers.map((link) => ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(link['caregiver_email']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _handleRemoveCaregiver(
                      link['patient_id'],
                      link['caregiver_email'],
                    ),
                  ),
                )),

          const Divider(thickness: 2),

          // =============================================================
          // SECTION 2 — Link to a family member (you are the caregiver)
          // =============================================================
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Link to a Family Member',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Enter a code someone shared with you to view their reminders, notes, and saved locations.'),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Enter code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _redeeming ? null : _handleRedeemCode,
                  child: _redeeming
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Link'),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'People You\'re Watching',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_loadingPatients)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_myPatients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Not watching anyone yet.'),
            )
          else
            ..._myPatients.map((link) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(link['patient_email']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _handleRemovePatient(
                      link['patient_id'],
                      link['patient_email'],
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientViewScreen(
                          patientId: link['patient_id'],
                          patientEmail: link['patient_email'],
                        ),
                      ),
                    );
                  },
                )),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}