// =====================================================================
// geofence_service.dart — two layers of "are we near a saved
// location?" checking:
//
// 1. A live position stream, for instant checks while the app is
//    open (unchanged from before).
// 2. A real Android background service (via flutter_foreground_task),
//    which keeps checking periodically even after the app is closed,
//    as long as Android allows the service to keep running.
//
// NOTE: some phones (Samsung especially) aggressively kill background
// services to save battery. If notifications stop arriving after the
// app has been closed for a long time, the fix is for the USER to
// manually exclude Clawd Bot from battery optimization in their
// phone's Settings - this is an Android/OEM limitation, not a bug in
// this code.
// =====================================================================

import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'db_helper.dart';
import 'notification_helper.dart';
import 'geofence_task_handler.dart';

class GeofenceService {
  GeofenceService._privateConstructor();
  static final GeofenceService instance = GeofenceService._privateConstructor();

  StreamSubscription<Position>? _positionSubscription;

  static const double _thresholdMeters = 100;
  static const Duration _cooldown = Duration(minutes: 30);
  final Map<int, DateTime> _lastNotified = {};

  // Call this once (we do it from the Dashboard) to start BOTH the
  // live foreground checking and the background service.
  Future<void> start() async {
    await _requestPermissions();
    await _startForegroundStream();
    await _startBackgroundService();
  }

  Future<void> _requestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // Try to upgrade to "Allow all the time" so the background
    // service can actually get a location fix. On many Android
    // versions this needs to be granted manually in Settings - the
    // app can ask, but can't force it.
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
  }

  Future<void> _startForegroundStream() async {
    if (_positionSubscription != null) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 20,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(_checkNearbyLocations);
  }

    Future<void> _startBackgroundService() async {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'geofence_background_channel',
          channelName: 'Clawd Bot Background Location',
          channelDescription:
              'Keeps watching for nearby saved locations even when the app is closed.',
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(60000),
          autoRunOnBoot: false,
          allowWakeLock: true,
        ),
      );

      final isRunning = await FlutterForegroundTask.isRunningService;
      if (isRunning) return;

            final result = await FlutterForegroundTask.startService(
        notificationTitle: 'Clawd Bot',
        notificationText: 'Watching for nearby saved locations',
        callback: startGeofenceCallback,
      );
      if (result is ServiceRequestFailure) {
        // ignore: avoid_print
        print('Background service FAILED: ${result.error}');
      } else {
        // ignore: avoid_print
        print('Background service started successfully: $result');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Background service failed to start: $e');
    }
  }

  // Runs an immediate one-off check against the phone's CURRENT
  // position - used right after adding a new location, so you can
  // test without having to physically move.
  Future<void> checkNow() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      await _checkNearbyLocations(position);
    } catch (e) {
      // ignore: avoid_print
      print('Geofence checkNow failed: $e');
    }
  }

  Future<void> _checkNearbyLocations(Position position) async {
    final locations = await DBHelper.instance.getObjectLocations();

    for (final loc in locations) {
      final lat = loc['latitude'];
      final lng = loc['longitude'];
      if (lat == null || lng == null) continue;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );

      if (distance <= _thresholdMeters) {
        final int id = loc['id'];
        final lastTime = _lastNotified[id];
        final now = DateTime.now();

        if (lastTime == null || now.difference(lastTime) > _cooldown) {
          _lastNotified[id] = now;

          final locationName = loc['location_name'] ?? 'a saved spot';
          final objectName = loc['object_name'];

          await NotificationHelper.instance.showInstantNotification(
            id: 900000000 + (id.abs() % 1000000),
            title: 'Clawd Bot',
            body: "You're near $locationName — don't forget your $objectName!",
          );

          await DBHelper.instance.logContext('nearby_location_alert');
        }
      }
    }
  }
}