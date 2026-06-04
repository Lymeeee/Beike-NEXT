import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/types/preferences.dart';

class ClassReminderService {
  static final ClassReminderService instance = ClassReminderService._();
  ClassReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Timer? _timer;
  String? _lastNotifiedKey;
  bool _initialized = false;

  bool get isRunning => _timer != null && _timer!.isActive;

  Future<void> requestPermission() async {
    if (!_initialized) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: '查看课程',
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;

    // Start if the preference says so
    final prefs = ServiceProvider.instance.storeService
        .getPref<AppSettings>('app_settings', AppSettings.fromJson);
    if (prefs?.classReminderEnabled == true) {
      start();
    }
  }

  void start() {
    stop();
    _lastNotifiedKey = null;
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _checkAndNotify());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _checkAndNotify() {
    final data = ServiceProvider.instance.storeService
        .getConfig<CurriculumIntegratedData>(
          'curriculum_data',
          CurriculumIntegratedData.fromJson,
        );
    if (data == null) return;

    final upcoming = data.getClassUpcoming();
    if (upcoming == null) return;

    final startTime = upcoming.getMinStartTime(data.allPeriods);
    if (startTime == null) return;

    final now = TimeOfDay.fromDateTime(DateTime.now());
    final minutesUntil = _minutesBetween(now, startTime);

    // Fire when 24-26 minutes before class (check every 60s, so 1-minute window)
    if (minutesUntil < 24 || minutesUntil > 26) return;

    // Prevent duplicate notifications
    final key = '${upcoming.day}-${upcoming.period}-${upcoming.className}';
    if (key == _lastNotifiedKey) return;
    _lastNotifiedKey = key;

    _showNotification(upcoming, startTime);
  }

  int _minutesBetween(TimeOfDay from, TimeOfDay to) {
    return (to.hour * 60 + to.minute) - (from.hour * 60 + from.minute);
  }

  Future<void> _showNotification(
      ClassItem course, TimeOfDay startTime) async {
    final timeStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final title = '距离下节课还有25分钟';
    final body = '${course.className}  $timeStr  ${course.locationName}';

    final androidDetails = const AndroidNotificationDetails(
      'class_reminder',
      '课程提醒',
      channelDescription: '课前25分钟提醒',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
      ),
      linux: const LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.normal,
      ),
    );

    await _plugin.show(
      course.className.hashCode, // unique ID per class
      title,
      body,
      platformDetails,
    );
  }

  void dispose() {
    stop();
  }
}
