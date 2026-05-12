import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Handles local notifications for the workout rest timer lifecycle.
class RestTimerNotificationService {
  RestTimerNotificationService._();

  static final RestTimerNotificationService instance =
      RestTimerNotificationService._();

  static const int _restTimerNotificationId = 42001;
  static const int _restTimerFinishedNotificationId = 42002;
  static const String _silentChannelId = 'rest_timer_silent';
  static const String _silentChannelName = 'Rest timer (silent)';
  static const String _silentChannelDescription =
      'Silent countdown while app is in background';
  static const String _alertChannelId = 'rest_timer_alert';
  static const String _alertChannelName = 'Rest timer alerts';
  static const String _alertChannelDescription =
      'Alerts when rest timer finishes';
  static const _athlosPrimaryColor = Color(0xFF6917B5);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _isUnavailable = false;
  bool _isTimeZoneInitialized = false;

  bool get supportsFrequentOngoingUpdates =>
      !kIsWeb &&
      defaultTargetPlatform != TargetPlatform.iOS &&
      defaultTargetPlatform != TargetPlatform.macOS;

  bool get usesScheduledFinishAlert => !supportsFrequentOngoingUpdates;

  Future<bool> init() async {
    if (_isUnavailable) return false;
    if (_isInitialized) return true;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_athlos'),
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
    );

    try {
      await _plugin.initialize(settings: initializationSettings);

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final iOSPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final macOSPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();

      await androidPlugin?.requestNotificationsPermission();
      await iOSPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await macOSPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _silentChannelId,
          _silentChannelName,
          description: _silentChannelDescription,
          importance: Importance.low,
          playSound: false,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          _alertChannelName,
          description: _alertChannelDescription,
          importance: Importance.high,
        ),
      );
    } on PlatformException {
      _isUnavailable = true;
      return false;
    }

    _isInitialized = true;
    return true;
  }

  Future<void> showOngoingRest({
    required String title,
    required String body,
  }) async {
    if (!await init()) return;
    await _plugin.show(
      id: _restTimerNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _silentChannelId,
          _silentChannelName,
          channelDescription: _silentChannelDescription,
          icon: 'ic_stat_athlos',
          color: _athlosPrimaryColor,
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          silent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: false,
          presentBadge: false,
          threadIdentifier: 'rest_timer',
          interruptionLevel: InterruptionLevel.passive,
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: false,
          presentBadge: false,
          threadIdentifier: 'rest_timer',
          interruptionLevel: InterruptionLevel.passive,
        ),
      ),
    );
  }

  Future<void> showRestFinished({
    required String title,
    required String body,
  }) async {
    if (!await init()) return;
    await _plugin.show(
      id: _restTimerNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          _alertChannelName,
          channelDescription: _alertChannelDescription,
          icon: 'ic_stat_athlos',
          color: _athlosPrimaryColor,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ongoing: false,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          threadIdentifier: 'rest_timer',
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          threadIdentifier: 'rest_timer',
        ),
      ),
    );
  }

  Future<void> scheduleRestFinished({
    required String title,
    required String body,
    required int afterSeconds,
  }) async {
    if (!await init() || afterSeconds <= 0) return;
    await _ensureTimeZoneInitialized();
    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: afterSeconds));
    await _plugin.zonedSchedule(
      id: _restTimerFinishedNotificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannelId,
          _alertChannelName,
          channelDescription: _alertChannelDescription,
          icon: 'ic_stat_athlos',
          color: _athlosPrimaryColor,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          ongoing: false,
          autoCancel: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          threadIdentifier: 'rest_timer',
        ),
        macOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
          presentBadge: true,
          threadIdentifier: 'rest_timer',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelScheduledRestFinished() async {
    await _plugin.cancel(id: _restTimerFinishedNotificationId);
  }

  Future<void> cancelAllForRestTimer() async {
    await _plugin.cancel(id: _restTimerNotificationId);
    await _plugin.cancel(id: _restTimerFinishedNotificationId);
  }

  Future<void> _ensureTimeZoneInitialized() async {
    if (_isTimeZoneInitialized) return;
    tz_data.initializeTimeZones();
    _isTimeZoneInitialized = true;
  }
}
