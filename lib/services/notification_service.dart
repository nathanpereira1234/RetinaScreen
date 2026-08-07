import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const String _channelId = 'follow_up_reminders';
const String _channelName = 'Follow-up reminders';
const String _channelDescription =
    'Reminders to follow up on patient referrals.';

/// Background-isolate tap handler. It runs in a separate isolate and cannot
/// drive the UI, so it is intentionally a no-op; foreground taps are handled
/// on the instance via [NotificationService._onForegroundTap].
@pragma('vm:entry-point')
void notificationBackgroundTap(NotificationResponse response) {}

/// Local notifications and follow-up scheduling (A15).
///
/// Payloads carry only a patient id — never PII — and are used to deep-link
/// back into the app when a reminder is tapped.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<int> _selected = StreamController<int>.broadcast();
  bool _initialized = false;

  /// Emits a patientId whenever a reminder is tapped (or opened the app).
  Stream<int> get onPatientSelected => _selected.stream;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (_) {
      // Platform channel unavailable (e.g. under `flutter test`); keep UTC.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onForegroundTap,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundTap,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();

    // Cold start from a tapped notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _emit(launch!.notificationResponse?.payload);
    }

    _initialized = true;
  }

  /// Fire an immediate notification — used to verify setup (A15 DoD).
  Future<void> showTest() {
    return _plugin.show(
      0,
      'RetinaScreen',
      'Test reminder — notifications are working.',
      _details(),
    );
  }

  /// Schedule a follow-up reminder. Uses inexact scheduling so no
  /// SCHEDULE_EXACT_ALARM permission is needed (see docs/PHASE1_NATIVE_SETUP).
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required int patientId,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime.from(when, tz.local);
    if (!target.isAfter(now)) {
      target = now.add(const Duration(seconds: 5));
    }
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      target,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$patientId',
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  void dispose() => _selected.close();

  void _onForegroundTap(NotificationResponse response) =>
      _emit(response.payload);

  void _emit(String? payload) {
    final id = int.tryParse(payload ?? '');
    if (id != null) _selected.add(id);
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
}
