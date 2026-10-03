// =====================================================================
// locations_tab.dart — Object Locations section of the Memory screen.
//
// UPDATED Aug 24: adds a "Use my current location" button.
//
// UPDATED Sep 30 (local DB): records a "last_modified" timestamp.
//
// UPDATED Sep 30 (cloud sync): "Add" and "Delete" try to push/remove
// the same location on the server.
//
// UPDATED Sep 30 (offline retry queue): a new location gets a
// temporary negative id and stays marked "unsynced" until it's
// actually pushed; deleting a server-known location that can't be
// deleted right now (e.g. offline) gets queued in pending_deletes,
// and the next "Sync Now" retries it automatically.
//
// UPDATED Oct 3 (geofencing): after saving a new location, runs an
// immediate geofence check against the current position, so you can
// test the "you're near a saved location" notification right away
// instead of waiting to physically move 20m+.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../db_helper.dart';
import '../geofence_service.dart';
import '../cloud_sync_service.dart';

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

    if (id > 0) {
      final result = await CloudSyncService.instance.deleteObjectLocation(id);
      if (!result['success']) {
        await DBHelper.instance.addPendingDelete('object_locations', id);
      }
    }

    _refreshLocations();
  }

  Future<Position?> _getCurrentLocation(
      void Function(String) onError) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      onError('Location services are turned off on this phone.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        onError('Location permission was denied.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      onError(
          'Location permission is permanently denied. Please enable it in Settings.');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (e) {
      onError('Could not get your current location. Please try again.');
      return null;
    }
  }

  void _showAddLocationDialog() {
    final objectController = TextEditingController();
    final locationController = TextEditingController();

    double? capturedLat;
    double? capturedLng;
    bool isFetchingLocation = false;
    String? locationStatusMessage;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      capturedLat != null
                          ? 'Location captured ✓'
                          : 'Use my current location',
                    ),
                    onPressed: isFetchingLocation
                        ? null
                        : () async {
                            setDialogState(() {
                              isFetchingLocation = true;
                              locationStatusMessage = null;
                            });

                            final position = await _getCurrentLocation(
                              (errorMsg) {
                                setDialogState(() {
                                  locationStatusMessage = errorMsg;
                                });
                              },
                            );

                            setDialogState(() {
                              isFetchingLocation = false;
                              if (position != null) {
                                capturedLat = position.latitude;
                                capturedLng = position.longitude;
                              }
                            });
                          },
                  ),
                  if (locationStatusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        locationStatusMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
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

                    // Temporary negative id - means "server doesn't
                    // know about this yet."
                    final tempId = DBHelper.instance.generateTempId();

                    final newLocation = {
                      'id': tempId,
                      'object_name': objectController.text.trim(),
                      'location_name': locationController.text.trim(),
                      'latitude': capturedLat,
                      'longitude': capturedLng,
                      'last_modified': DateTime.now().toIso8601String(),
                      'synced': 0,
                    };

                    await DBHelper.instance.insertObjectLocation(newLocation);

                    // Try to push it right now. If it succeeds (we're
                    // online), swap the local row over to the
                    // server's real id immediately. If it fails
                    // (offline), it just stays queued with its
                    // negative id until the next Sync Now.
                    final pushResult = await CloudSyncService.instance.createObjectLocation({
                      'object_name': newLocation['object_name'],
                      'location_name': newLocation['location_name'],
                      'latitude': newLocation['latitude'],
                      'longitude': newLocation['longitude'],
                    });

                    if (pushResult['success']) {
                      final serverData = pushResult['data'];
                      await DBHelper.instance.replaceObjectLocationId(tempId, {
                        'id': serverData['id'],
                        'object_name': serverData['object_name'],
                        'location_name': serverData['location_name'],
                        'latitude': serverData['latitude'],
                        'longitude': serverData['longitude'],
                        'last_modified': serverData['last_modified'],
                        'synced': 1,
                      });
                    }

                    Navigator.pop(context);
                    _refreshLocations();

                    // NEW: immediately check if we're near this (or
                    // any other) saved location, instead of waiting
                    // for the phone to move 20m+.
                    // ignore: unawaited_futures
                    GeofenceService.instance.checkNow();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
                      final hasCoordinates = location['latitude'] != null;
                      return ListTile(
                        leading: Icon(
                          Icons.place,
                          color: hasCoordinates ? Colors.blue : null,
                        ),
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