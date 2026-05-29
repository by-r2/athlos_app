import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Which workout timer alert is being delivered.
enum WorkoutTimerAlertKind {
  restFinished,
  goalReached,
}

/// Handles local notifications for rest and duration-goal timers.
///
/// Custom sounds live in:
/// - Android: `android/app/src/main/res/raw/`
/// - iOS: bundled under `ios/Runner/` (referenced by filename).
class RestTimerNotificationService {
  RestTimerNotificationService._();

  static final RestTimerNotificationService instance =
      RestTimerNotificationService._();

  static const int _restTimerNotificationId = 42001;
  static const int _restTimerFinishedNotificationId = 42002;
  static const int _goalTimerFinishedNotificationId = 42003;

  static const String _silentChannelId = 'rest_timer_silent';
  static const String _silentChannelName = 'Rest timer (silent)';
  static const String _silentChannelDescription =
      'Silent countdown while app is in background';

  static const String _restAlertChannelId = 'rest_timer_alert_v2';
  static const String _restAlertChannelName = 'Rest timer alerts';
  static const String _restAlertChannelDescription =
      'Bronze herald when rest finishes';

  static const String _goalAlertChannelId = 'goal_timer_alert_v2';
  static const String _goalAlertChannelName = 'Duration goal alerts';
  static const String _goalAlertChannelDescription =
      'Lyre triumph when a duration goal is reached';

  static const String _restSoundAndroid = 'rest_finished';
  static const String _goalSoundAndroid = 'goal_reached';
  static const String _restSoundIos = 'rest_finished.wav';
  static const String _goalSoundIos = 'goal_reached.wav';

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
        AndroidNotificationChannel(
          _restAlertChannelId,
          _restAlertChannelName,
          description: _restAlertChannelDescription,
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(_restSoundAndroid),
        ),
      );
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _goalAlertChannelId,
          _goalAlertChannelName,
          description: _goalAlertChannelDescription,
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(_goalSoundAndroid),
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
    await _showAlert(
      notificationId: _restTimerNotificationId,
      title: title,
      body: body,
      kind: WorkoutTimerAlertKind.restFinished,
    );
  }

  Future<void> showGoalReached({
    required String title,
    required String body,
  }) async {
    await _showAlert(
      notificationId: _goalTimerFinishedNotificationId,
      title: title,
      body: body,
      kind: WorkoutTimerAlertKind.goalReached,
    );
  }

  Future<void> scheduleRestFinished({
    required String title,
    required String body,
    required int afterSeconds,
  }) async {
    await _scheduleAlert(
      notificationId: _restTimerFinishedNotificationId,
      title: title,
      body: body,
      afterSeconds: afterSeconds,
      kind: WorkoutTimerAlertKind.restFinished,
    );
  }

  Future<void> scheduleGoalReached({
    required String title,
    required String body,
    required int afterSeconds,
  }) async {
    await _scheduleAlert(
      notificationId: _goalTimerFinishedNotificationId,
      title: title,
      body: body,
      afterSeconds: afterSeconds,
      kind: WorkoutTimerAlertKind.goalReached,
    );
  }

  Future<void> cancelScheduledRestFinished() async {
    await _plugin.cancel(id: _restTimerFinishedNotificationId);
  }

  Future<void> cancelScheduledGoalReached() async {
    await _plugin.cancel(id: _goalTimerFinishedNotificationId);
  }

  Future<void> cancelAllForRestTimer() async {
    await _plugin.cancel(id: _restTimerNotificationId);
    await _plugin.cancel(id: _restTimerFinishedNotificationId);
  }

  Future<void> cancelAllForGoalTimer() async {
    await _plugin.cancel(id: _goalTimerFinishedNotificationId);
  }

  Future<void> cancelAllWorkoutTimerNotifications() async {
    await cancelAllForRestTimer();
    await cancelAllForGoalTimer();
  }

  Future<void> _showAlert({
    required int notificationId,
    required String title,
    required String body,
    required WorkoutTimerAlertKind kind,
  }) async {
    if (!await init()) return;
    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: _alertDetails(kind),
    );
  }

  Future<void> _scheduleAlert({
    required int notificationId,
    required String title,
    required String body,
    required int afterSeconds,
    required WorkoutTimerAlertKind kind,
  }) async {
    if (!await init() || afterSeconds <= 0) return;
    await _ensureTimeZoneInitialized();
    final scheduledDate = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: afterSeconds));
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: _alertDetails(kind),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  NotificationDetails _alertDetails(WorkoutTimerAlertKind kind) {
    final isRest = kind == WorkoutTimerAlertKind.restFinished;
    final androidChannelId =
        isRest ? _restAlertChannelId : _goalAlertChannelId;
    final androidChannelName =
        isRest ? _restAlertChannelName : _goalAlertChannelName;
    final androidChannelDescription = isRest
        ? _restAlertChannelDescription
        : _goalAlertChannelDescription;
    final androidSound = isRest ? _restSoundAndroid : _goalSoundAndroid;
    final iosSound = isRest ? _restSoundIos : _goalSoundIos;
    final threadId = isRest ? 'rest_timer' : 'goal_timer';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: androidChannelDescription,
        icon: 'ic_stat_athlos',
        color: _athlosPrimaryColor,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(androidSound),
        enableVibration: true,
        ongoing: false,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        sound: iosSound,
        presentBadge: true,
        threadIdentifier: threadId,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentSound: true,
        sound: iosSound,
        presentBadge: true,
        threadIdentifier: threadId,
      ),
    );
  }

  Future<void> _ensureTimeZoneInitialized() async {
    if (_isTimeZoneInitialized) return;
    tz_data.initializeTimeZones();
    _isTimeZoneInitialized = true;
  }
}
