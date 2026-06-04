import 'dart:convert';
import 'package:flutter/services.dart';
import '/types/courses.dart';

class WidgetUpdater {
  static const _channel = MethodChannel('com.lyme.beikenext/widget');

  static final WidgetUpdater _instance = WidgetUpdater._internal();
  factory WidgetUpdater() => _instance;
  WidgetUpdater._internal();

  void updateFromCurriculum(CurriculumIntegratedData? data) {
    final payload = <String, dynamic>{
      'hasData': data != null,
    };
    if (data != null) {
      payload.addAll(data.toJson());
      payload['termSeason'] = data.currentTerm.season;
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
