import 'dart:convert';
import 'package:flutter/services.dart';
import '/types/courses.dart';

class WidgetUpdater {
  static const _channel = MethodChannel('com.lyme.beikenext/widget');

  static final WidgetUpdater _instance = WidgetUpdater._internal();
  factory WidgetUpdater() => _instance;
  WidgetUpdater._internal();

  void updateFromCurriculum(CurriculumIntegratedData? data,
      {List<ClassItem>? customCourses}) {
    final payload = <String, dynamic>{
      'hasData': data != null,
    };
    if (data != null) {
      payload.addAll(data.toJson());
      payload['termSeason'] = data.currentTerm.season;

      // Pass summer term start date from settings
      if (data.currentTerm.season >= 3 && data.summerTermStartDate != null) {
        final start = data.summerTermStartDate!;
        payload['summerTermStartYear'] = start.year;
        payload['summerTermStartMonth'] = start.month;
        payload['summerTermStartDay'] = start.day;
      }

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

  void updateExams(List<ExamInfo> exams) {
    final now = DateTime.now();
    ExamInfo? ongoing;
    ExamInfo? upcoming;
    DateTime? upcomingStart;

    for (final exam in exams) {
      final start = exam.getStartTime();
      final end = exam.getEndTime();
      if (start == null || end == null) continue;
      if (now.isAfter(start) && now.isBefore(end)) {
        ongoing = exam;
      } else if (start.isAfter(now) &&
          (upcomingStart == null || start.isBefore(upcomingStart))) {
        upcoming = exam;
        upcomingStart = start;
      }
    }

    final displayExam = ongoing ?? upcoming;
    final payload = <String, dynamic>{
      'hasData': true,
      'examMode': true,
    };

    if (displayExam != null) {
      final label = ongoing != null ? '考试进行中' : '即将考试';
      payload['examLabel'] = label;
      payload['examName'] = displayExam.courseName;
      payload['examTime'] = displayExam.examTime;
      payload['examDate'] = displayExam.examDateDisplay;
      payload['examDay'] = displayExam.examDayName;
      payload['examRoom'] = displayExam.examRoom;
    }

    _channel.invokeMethod('updateCurriculumData', json.encode(payload));
  }
}
