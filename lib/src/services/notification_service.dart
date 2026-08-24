import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

final class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      linux: LinuxInitializationSettings(defaultActionName: 'Open Happy Wakey'),
      windows: WindowsInitializationSettings(
        appName: 'Happy Wakey',
        appUserModelId: 'HappyWakey.DailyCommandCenter.1',
        guid: '79fcffef-b2fa-4fb5-bd0e-2686447cd131',
      ),
      web: WebInitializationSettings(),
    );
    _initialized = await _plugin.initialize(settings: settings) ?? false;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    if (kIsWeb) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                WebFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false,
      TargetPlatform.iOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false,
      TargetPlatform.macOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false,
      _ => true,
    };
  }

  Future<void> showTest() async {
    if (!_initialized) await initialize();
    await _plugin.show(
      id: 20260824,
      title: 'Happy Wakey is ready',
      body: 'Your daily reminders can reach you on this device.',
      notificationDetails: _details,
    );
  }

  Future<void> scheduleCalendar(
    List<CalendarEvent> events,
    ReminderSettings settings,
  ) async {
    if (!_initialized) await initialize();
    await _plugin.cancelAll();
    if (!settings.enabled) return;
    final now = DateTime.now();
    var count = 0;
    for (final event in events) {
      if (event.allDay || event.isCancelled || !event.start.isAfter(now)) {
        continue;
      }
      for (final offset in settings.offsetsMinutes) {
        final trigger = event.start.subtract(Duration(minutes: offset));
        if (!trigger.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: _stableId(
            '${event.provider}|${event.id}|${event.start.toUtc()}|$offset',
          ),
          title: event.title,
          body:
              'Starts in $offset minute${offset == 1 ? '' : 's'}${event.location == null ? '' : ' · ${event.location}'}',
          scheduledDate: tz.TZDateTime.from(trigger.toUtc(), tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: event.joinUrl?.toString() ?? event.eventUrl?.toString(),
        );
        count += 1;
        if (count >= 64) return;
      }
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'calendar-reminders',
      'Calendar reminders',
      channelDescription: 'Upcoming Happy Wakey calendar events',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
    linux: LinuxNotificationDetails(),
    windows: WindowsNotificationDetails(
      scenario: WindowsNotificationScenario.reminder,
    ),
    web: WebNotificationDetails(),
  );

  int _stableId(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
