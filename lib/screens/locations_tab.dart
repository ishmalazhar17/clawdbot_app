// =====================================================================
// locations_tab.dart — the Object Locations section of the Memory
// screen. Add, view, and delete saved locations for objects (e.g.
// "keys" -> "kitchen drawer").
//
// Real GPS coordinates come later (Aug 24) — for now this is simple
// text-based location tracking, which is still genuinely useful on
// its own.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';

class LocationsTab extends StatefulWidget {
  const LocationsTab({super.key});

  @override
  State<LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<LocationsTab> {
  List<Map<String, dynamic>> _locations = [];

  @override
  void initState() {
    super.initState();
    _refreshLocations();
  }

  Future<void> _refreshLocations() async {
    final data = await DBHelper.instance.getObjectLocations();
    setState(() {
      _locations = data;
    });
  }
  Future<void> _deleteLocation(int id) async {
    await DBHelper.instance.deleteObjectLocation(id);
    _refreshLocations();
  }

  void _showAddLocationDialog() {
    final objectController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Object Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: objectController,
                decoration: const InputDecoration(
                  labelText: 'Object',
                  hintText: 'e.g. keys, wallet, glasses',
                ),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. kitchen drawer, hallway table',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (objectController.text.trim().isEmpty) return;

                await DBHelper.instance.insertObjectLocation({
                  'object_name': objectController.text.trim(),
                  'location_name': locationController.text.trim(),
                  'latitude': null,  // real GPS comes Aug 24
                  'longitude': null,
                });

                Navigator.pop(context);
                _refreshLocations();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLocationDialog,
        child: const Icon(Icons.add),
      ),
      body: _locations.isEmpty
          ? const Center(child: Text('No saved locations yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                final location = _locations[index];
                return ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(location['object_name']),
                  subtitle: Text(location['location_name'] ?? 'No location set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteLocation(location['id']),
                  ),
                );
              },
            ),
    );
  }
}