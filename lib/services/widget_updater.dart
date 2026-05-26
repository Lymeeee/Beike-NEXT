import 'dart:convert';
import 'package:flutter/services.dart';
import '/types/courses.dart';

class WidgetUpdater {
  static const _channel = MethodChannel('cn.thebeike.app/widget');

  static final WidgetUpdater _instance = WidgetUpdater._internal();
  factory WidgetUpdater() => _instance;
  WidgetUpdater._internal();

  void updateFromCurriculum(CurriculumIntegratedData? data) {
    if (data == null) {
      _send({
        'hasClass': false,
      });
      return;
    }

    final ongoingClass = data.getClassOngoing();
    final upcomingClass = data.getClassUpcoming();
    final targetClass = ongoingClass ?? upcomingClass;

    if (targetClass == null) {
      _send({
        'hasClass': false,
      });
      return;
    }

    final startTime = targetClass.getMinStartTime(data.allPeriods);
    final endTime = targetClass.getMaxEndTime(data.allPeriods);

    String? timeRange;
    if (startTime != null && endTime != null) {
      timeRange =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    }

    _send({
      'hasClass': true,
      'label': '接下来',
      'className': targetClass.className,
      'timeRange': timeRange ?? targetClass.periodName,
      'location': targetClass.locationName,
      'teacher': targetClass.teacherName,
    });
  }

  void _send(Map<String, dynamic> data) {
    _channel.invokeMethod('updateUpcomingClass', json.encode(data));
  }
}
