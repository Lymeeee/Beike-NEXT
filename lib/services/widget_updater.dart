import 'dart:convert';
import 'package:flutter/services.dart';
import '/types/courses.dart';

class WidgetUpdater {
  static const _channel = MethodChannel('cn.thebeike.app/widget');

  static final WidgetUpdater _instance = WidgetUpdater._internal();
  factory WidgetUpdater() => _instance;
  WidgetUpdater._internal();

  void updateFromCurriculum(CurriculumIntegratedData? data) {
    final payload = <String, dynamic>{
      'hasData': data != null,
    };
    if (data != null) {
      payload.addAll(data.toJson());
    }
    _channel.invokeMethod('updateCurriculumData', json.encode(payload));
  }
}
