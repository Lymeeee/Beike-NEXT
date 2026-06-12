import 'dart:convert';
import 'package:flutter/services.dart';
import '/types/courses.dart';

class WidgetUpdater {
  static const _channel = MethodChannel('com.lyme.beikenext/widget');

  static final WidgetUpdater _instance = WidgetUpdater._internal();
  factory WidgetUpdater() => _instance;
  WidgetUpdater._internal();

  void updateFromCurriculum(CurriculumIntegratedData? data, {List<ClassItem>? customCourses}) {
    final payload = <String, dynamic>{
      'hasData': data != null,
    };
    if (data != null) {
      payload.addAll(data.toJson());
      payload['termSeason'] = data.currentTerm.season;
      if (customCourses != null && customCourses.isNotEmpty) {
        final allClasses = List<Map<String, dynamic>>.from(payload['allClasses']);
        for (final cc in customCourses) {
          allClasses.add(cc.toJson());
        }
        payload['allClasses'] = allClasses;
      }
    }
    _channel.invokeMethod('updateCurriculumData', json.encode(payload));
  }

  void updateHoliday() {
    final payload = <String, dynamic>{
      'hasData': true,
      'holidayMode': true,
    };
    _channel.invokeMethod('updateCurriculumData', json.encode(payload));
  }
}
