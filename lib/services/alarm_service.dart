import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const String meetUrl = "https://meet.google.com/vtu-qgxk-zrv";
  static const String channelId = "yfc_fellowship_alarm_channel_v2";
  static const String channelName = "YFC Fellowship Alarms";

  bool _isLoopActive = false;
  final ValueNotifier<bool> isAlarmRingingNotifier = ValueNotifier<bool>(false);
  bool get isAlarmRinging => isAlarmRingingNotifier.value;
  Timer? _fiveMinRecurringTimer;
  int _currentIntervalCount = 0;
  static const int maxLoopIntervals = 6; // 30 minutes total (5 min * 6)

  // Granular Alarm Selection Preferences
  bool _isMorningAlarmEnabled = true;
  bool _isEveningAlarmEnabled = true;

  bool get isMorningAlarmEnabled => _isMorningAlarmEnabled;
  bool get isEveningAlarmEnabled => _isEveningAlarmEnabled;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    await loadAlarmPreferences();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createNotificationChannel();
    await checkAndPerformDailyMidnightReset();
    await scheduleDailyLiveEventsReminders();
    await schedulePreServiceWarningAlarms();
    await scheduleExactDailyAlarms();
  }

  Future<void> schedulePreServiceWarningAlarms() async {
    try {
      final now = DateTime.now();
      final morningWarning = DateTime(now.year, now.month, now.day, 4, 55);
      final eveningWarning = DateTime(now.year, now.month, now.day, 20, 55);

      final targetMorning = now.isAfter(morningWarning) ? morningWarning.add(const Duration(days: 1)) : morningWarning;
      final targetEvening = now.isAfter(eveningWarning) ? eveningWarning.add(const Duration(days: 1)) : eveningWarning;

      Timer(targetMorning.difference(now), () {
        _triggerPreServiceChime(isMorning: true);
        schedulePreServiceWarningAlarms();
      });

      Timer(targetEvening.difference(now), () {
        _triggerPreServiceChime(isMorning: false);
        schedulePreServiceWarningAlarms();
      });
    } catch (_) {}
  }

  void _triggerPreServiceChime({required bool isMorning}) {
    showHeadsUpNotification(
      notificationId: isMorning ? 455 : 855,
      title: isMorning ? "⏰ 5-Min Warning: Morning Prayer" : "⏰ 5-Min Warning: Evening Bible Study",
      body: isMorning
          ? "Morning Prayer starts in 5 minutes (5:00 AM IST)! Prepare to join."
          : "Evening Bible Study starts in 5 minutes (9:00 PM IST)! Prepare to join.",
      payload: meetUrl,
    );
  }

  Future<void> checkAndPerformDailyMidnightReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncDate = prefs.getString('last_alarm_auto_sync_date');
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (lastSyncDate != todayStr) {
        _isMorningAlarmEnabled = true;
        _isEveningAlarmEnabled = true;
        await prefs.setBool('is_morning_alarm_enabled', true);
        await prefs.setBool('is_evening_alarm_enabled', true);
        await prefs.setString('last_alarm_auto_sync_date', todayStr);
      }
    } catch (_) {}
  }

  Future<void> scheduleDailyLiveEventsReminders() async {
    // Automatically re-arm local notification triggers for active live events
    try {
      if (_isMorningAlarmEnabled) {
        await showHeadsUpNotification(
          notificationId: 701,
          title: "🌅 YFC Morning Prayer Sync",
          body: "Live Morning Prayer auto-scheduled daily for 5:00 AM IST.",
        );
      }
      if (_isEveningAlarmEnabled) {
        await showHeadsUpNotification(
          notificationId: 702,
          title: "📖 YFC Evening Bible Study Sync",
          body: "Live Evening Bible Study auto-scheduled daily for 9:00 PM IST.",
        );
      }
    } catch (_) {}
  }

  Future<void> loadAlarmPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMorningAlarmEnabled = prefs.getBool('is_morning_alarm_enabled') ?? true;
      _isEveningAlarmEnabled = prefs.getBool('is_evening_alarm_enabled') ?? true;
    } catch (_) {}
  }

  Future<void> setMorningAlarmEnabled(bool enabled) async {
    _isMorningAlarmEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_morning_alarm_enabled', enabled);
    } catch (_) {}
    if (!enabled && isAlarmRinging) {
      stopAlarmLoop();
    }
  }

  Future<void> setEveningAlarmEnabled(bool enabled) async {
    _isEveningAlarmEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_evening_alarm_enabled', enabled);
    } catch (_) {}
    if (!enabled && isAlarmRinging) {
      stopAlarmLoop();
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'yfc_fellowship_alarm_channel_v2',
      'YFC Fellowship Alarms',
      description: 'Alarms for Morning Prayer and Evening Bible Study',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('shofar_alarm'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
    );

    const headsUpChannel = AndroidNotificationChannel(
      'yfc_push_notifications_channel_v1',
      'YFC Fellowship Alerts & Mentions',
      description: 'High-priority heads-up notifications for chat messages, prayer alerts, and announcements',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);
    await androidPlugin?.createNotificationChannel(headsUpChannel);
  }

  Future<void> scheduleExactDailyAlarms() async {
    try {
      final now = tz.TZDateTime.now(tz.local);

      // Morning Prayer at 4:55 AM (5 min warning)
      var morningTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 4, 55);
      if (morningTime.isBefore(now)) {
        morningTime = morningTime.add(const Duration(days: 1));
      }

      // Evening Bible Study at 8:55 PM (20:55 - 5 min warning)
      var eveningTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 55);
      if (eveningTime.isBefore(now)) {
        eveningTime = eveningTime.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'yfc_fellowship_alarm_channel_v2',
        'YFC Fellowship Alarms',
        channelDescription: 'Alarms for Morning Prayer and Evening Bible Study',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('shofar_alarm'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      );

      const details = NotificationDetails(android: androidDetails);

      if (_isMorningAlarmEnabled) {
        await _notificationsPlugin.zonedSchedule(
          455,
          "⏰ 5-Min Warning: Morning Prayer",
          "Morning Prayer starts in 5 minutes (5:00 AM IST)! Prepare to join.",
          morningTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      if (_isEveningAlarmEnabled) {
        await _notificationsPlugin.zonedSchedule(
          855,
          "⏰ 5-Min Warning: Evening Bible Study",
          "Evening Bible Study starts in 5 minutes (9:00 PM IST)! Prepare to join.",
          eveningTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint("[AlarmService ZonedSchedule Error] $e");
    }
  }

  // Show High-Priority Heads-Up Android Notification (WhatsApp style)
  static Future<void> showHeadsUpNotification({
    required String title,
    required String body,
    String? payload,
    int? notificationId,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'yfc_push_notifications_channel_v1',
      'YFC Fellowship Alerts & Mentions',
      channelDescription: 'High-priority heads-up notifications for chat messages, prayer alerts, and announcements',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _instance._notificationsPlugin.show(
      notificationId ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Trigger 5-minute recurring loop block for Morning Prayer (5:00-5:30 AM) or Evening Study (9:00-9:30 PM)
  Future<void> startPrayerBlockAlarmLoop({required bool isMorning}) async {
    if (isMorning && !_isMorningAlarmEnabled) return;
    if (!isMorning && !_isEveningAlarmEnabled) return;
    if (_isLoopActive) return;

    _isLoopActive = true;
    _currentIntervalCount = 0;

    // Acquire WakeLock to turn on/keep screen awake for high-priority alarm
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    // Play local peaceful instrumental Christian audio overriding DND continuously in loop
    await _playAudioTrack(isMorning ? 'audio/morning_hymn.mp3' : 'audio/evening_chimes.mp3');

    // Trigger initial notification
    await _showAlarmNotification(
      title: isMorning ? "🌅 YFC Morning Prayer Alert!" : "📖 YFC Evening Bible Study Alert!",
      body: isMorning 
          ? "Time to start the day with God! Click below to join Google Meet."
          : "Gather for evening fellowship! Click below to join Google Meet.",
    );

    // Schedule 5-minute recurring interval timer for up to 30 minutes (6 triggers)
    _fiveMinRecurringTimer?.cancel();
    _fiveMinRecurringTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if ((isMorning && !_isMorningAlarmEnabled) || (!isMorning && !_isEveningAlarmEnabled)) {
        stopAlarmLoop();
        return;
      }

      _currentIntervalCount++;
      if (_currentIntervalCount >= maxLoopIntervals) {
        stopAlarmLoop();
        return;
      }

      await _playAudioTrack(isMorning ? 'audio/morning_hymn.mp3' : 'audio/evening_chimes.mp3');
      await _showAlarmNotification(
        title: isMorning 
            ? "🌅 Reminder (${_currentIntervalCount * 5}m): YFC Morning Prayer"
            : "📖 Reminder (${_currentIntervalCount * 5}m): YFC Evening Bible Study",
        body: "Fellowship is live right now on Google Meet!",
      );
    });
  }

  Future<void> _playAudioTrack(String assetPath) async {
    try {
      isAlarmRingingNotifier.value = true;
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Continuous loop until dismissed or joined
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm, // Overrides DND
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
      ));
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {}
  }

  Future<void> _showAlarmNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: "High-priority alarm loop notification",
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true, // Wake-lock bypass lock screen
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('shofar_alarm'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      actions: [
        AndroidNotificationAction(
          'action_join_meet',
          'Join Google Meet Now 🎥',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'action_dismiss',
          'Dismiss for Today ❌',
          cancelNotification: true,
        ),
      ],
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      888,
      title,
      body,
      notificationDetails,
      payload: meetUrl,
    );
  }

  // Handle action button click & notification body tap
  void _onNotificationResponse(NotificationResponse details) async {
    if (details.actionId == 'action_join_meet' || details.payload == meetUrl || details.actionId == null || details.actionId == '') {
      stopAlarmLoop();
      await launchGoogleMeet();
    } else if (details.actionId == 'action_dismiss') {
      stopAlarmLoop();
    }
  }

  // Launch Google Meet URL directly in external application
  static Future<void> launchGoogleMeet() async {
    final Uri uri = Uri.parse(meetUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // Explicit stop alarm method (alias for stopAlarmLoop)
  void stopAlarm() {
    stopAlarmLoop();
  }

  // Clear remaining 5-minute interval alerts for current block
  void stopAlarmLoop() {
    _isLoopActive = false;
    isAlarmRingingNotifier.value = false;
    _fiveMinRecurringTimer?.cancel();
    _audioPlayer.stop();
    _notificationsPlugin.cancel(888);
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'action_join_meet' || notificationResponse.payload == AlarmService.meetUrl || notificationResponse.actionId == null || notificationResponse.actionId == '') {
    await AlarmService.launchGoogleMeet();
  }
}
