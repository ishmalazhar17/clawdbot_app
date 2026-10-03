// =====================================================================
// notification_helper.dart — sets up and schedules local phone
// notifications for reminders.
//
// Like db_helper.dart, this is a SINGLETON — one shared instance for
// the whole app, so we don't set up the notification system more
// than once.
//
// UPDATED Oct 3: added showInstantNotification(), used by the new
// geofencing feature to alert the user immediately when they're near
// a saved object location (as opposed to scheduleNotification, which
// fires at a specific future date/time).
// =====================================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationHelper {
  NotificationHelper._privateConstructor();
  static final NotificationHelper instance =
      NotificationHelper._privateConstructor();

  // This is the actual plugin object that talks to Android's
  // notification system under the hood.
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Call this ONCE when the app starts (we'll do that in main.dart).
  // Sets up the notification system and asks for permission.
  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // Schedules a notification to appear at a specific date/time.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Reminders',
      channelDescription: 'Notifications for Clawd Bot reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // ---------------------------------------------------------------
  // NEW: fires a notification RIGHT NOW (no scheduling), used for
  // "you're near a saved location" geofencing alerts.
  // ---------------------------------------------------------------
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Nearby Location Alerts',
      channelDescription: 'Alerts when you are near a saved object location',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  // Cancels a scheduled notification (used when a reminder is deleted).
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }
}