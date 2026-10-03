// =====================================================================
// geofence_task_handler.dart — the code that actually runs INSIDE the
// background service (see geofence_service.dart for what starts it).
//
// This is what keeps checking "am I near a saved location?" even
// after the app is closed/swiped away, as long as Android hasn't
// killed the background service (which some phones, especially
// Samsung, do aggressively to save battery - see the note in
// geofence_service.dart).
// =====================================================================

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'db_helper.dart';
import 'notification_helper.dart';

// This MUST be a top-level function (not inside a class) - Android
// calls this directly to start the background task.
@pragma('vm:entry-point')
void startGeofenceCallback() {
  FlutterForegroundTask.setTaskHandler(GeofenceTaskHandler());
}

class GeofenceTaskHandler extends TaskHandler {
  static const double _thresholdMeters = 100;
  static const Duration _cooldown = Duration(minutes: 30);
  final Map<int, DateTime> _lastNotified = {};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Nothing special needed when the background service first starts.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // ignore: discarded_futures
    _checkNearbyLocations();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Nothing to clean up.
  }

  Future<void> _checkNearbyLocations() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
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
    } catch (e) {
      // ignore: avoid_print
      print('Background geofence check failed: $e');
    }
  }
}