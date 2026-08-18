// =====================================================================
// locations_tab.dart — Object Locations section of the Memory screen.
//
// AUG 17 UPDATE: adds a search bar that filters by object or location
// name.
// =====================================================================

import 'package:flutter/material.dart';
import '../db_helper.dart';

class LocationsTab extends StatefulWidget {
  const LocationsTab({super.key});

  @override
  State<LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<LocationsTab> {
  List<Map<String, dynamic>> _allLocations = [];
  List<Map<String, dynamic>> _filteredLocations = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshLocations();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshLocations() async {
    final data = await DBHelper.instance.getObjectLocations();
    setState(() {
      _allLocations = data;
    });
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = _allLocations;
      } else {
        _filteredLocations = _allLocations.where((loc) {
          final object = loc['object_name'].toString().toLowerCase();
          final location = (loc['location_name'] ?? '').toString().toLowerCase();
          return object.contains(query) || location.contains(query);
        }).toList();
      }
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
                  'latitude': null,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _filteredLocations.isEmpty
                ? const Center(child: Text('No locations found.'))
                : ListView.builder(
                    itemCount: _filteredLocations.length,
                    itemBuilder: (context, index) {
                      final location = _filteredLocations[index];
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
          ),
        ],
      ),
    );
  }
}