// =====================================================================
// locations_tab.dart — Object Locations section of the Memory screen.
//
// UPDATED Aug 24: adds a "Use my current location" button.
//
// UPDATED Sep 30 (local DB): records a "last_modified" timestamp.
//
// UPDATED Sep 30 (cloud sync): "Add" and "Delete" now also try to
// push/remove the same location on the server. Fails silently if
// offline.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../db_helper.dart';
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
    // ignore: unawaited_futures
    CloudSyncService.instance.deleteObjectLocation(id);
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

                    final newLocation = {
                      'object_name': objectController.text.trim(),
                      'location_name': locationController.text.trim(),
                      'latitude': capturedLat,
                      'longitude': capturedLng,
                      'last_modified': DateTime.now().toIso8601String(),
                    };

                    await DBHelper.instance.insertObjectLocation(newLocation);

                    // ignore: unawaited_futures
                    CloudSyncService.instance.createObjectLocation(newLocation);

                    Navigator.pop(context);
                    _refreshLocations();
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