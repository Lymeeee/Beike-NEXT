import 'dart:convert';
import 'package:flutter/services.dart';
import '/types/courses.dart';

class WidgetUpdater {
  static const _channel = MethodChannel('com.lyme.beikenext/widget');

  static final WidgetUpdater _instance = WidgetUpdater._internal();
  factory WidgetUpdater() => _instance;
  WidgetUpdater._internal();

  static final _campusPattern = RegExp(r'【[^】]*】');

  // 校区名以中文中括号包裹，小组件中不展示
  static String _stripCampus(String location) =>
      location.replaceAll(_campusPattern, '').trim();

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

      final allClasses = <Map<String, dynamic>>[
        ...data.allClasses.map((c) => c.toJson()),
        ...?customCourses?.map((c) => c.toJson()),
      ];
      for (final course in allClasses) {
        final location = course['locationName'];
        if (location is String && location.isNotEmpty) {
          course['locationName'] = _stripCampus(location);
        }
      }
      payload['allClasses'] = allClasses;
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
      payload['examRoom'] = _stripCampus(displayExam.examRoom);
    }

    _channel.invokeMethod('updateCurriculumData', json.encode(payload));
  }
}
