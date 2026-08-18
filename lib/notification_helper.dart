// =====================================================================
// notification_helper.dart — sets up and schedules local phone
// notifications for reminders.
//
// Like db_helper.dart, this is a SINGLETON — one shared instance for
// the whole app, so we don't set up the notification system more
// than once.
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
    // tz.initializeTimeZones() loads timezone data — required because
    // scheduling a notification for "6pm" needs to know what timezone
    // "6pm" actually means.
    tz.initializeTimeZones();

    // Android-specific setup: tells the plugin which icon to show in
    // the notification (using the app's default launcher icon).
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    // On Android 13+, apps must explicitly REQUEST permission to post
    // notifications — this triggers that system permission popup.
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  // Schedules a notification to appear at a specific date/time.
  //
  // id: a unique number for this notification (we'll use the
  //     reminder's database id, so each reminder gets its own
  //     notification that can be individually cancelled later).
  // title/body: the text shown in the notification.
  // scheduledDate: when it should actually fire.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'reminders_channel', // internal channel id
      'Reminders', // channel name shown in Android's notification settings
      channelDescription: 'Notifications for Clawd Bot reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

       await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // Converts the plain DateTime into a timezone-aware time, using
      // the device's local timezone.
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // Cancels a scheduled notification (used when a reminder is deleted).
  Future<void> cancelNotification(int id) async {
   await _plugin.cancel(id: id);
  }
}