import 'package:flutter/material.dart';

import '/services/store/base.dart';
import '/types/courses.dart';
import '/types/library.dart';
import '/utils/exam_helper.dart';

enum CockpitClassStatus { past, ongoing, next, upcoming, unknown }

/// 某个大节的今日课程（同一大节的冲突课程合并为一条）
class CockpitClassSlot {
  final int period; // 大节号
  final String periodName;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final List<ClassItem> classes;

  /// 由 [groupTodaySlots] 按当前时间标注，随快照重建
  CockpitClassStatus status = CockpitClassStatus.unknown;

  CockpitClassSlot({
    required this.period,
    required this.periodName,
    required this.start,
    required this.end,
    required this.classes,
  });

  int? get startMinutes =>
      start == null ? null : start!.hour * 60 + start!.minute;

  int? get endMinutes => end == null ? null : end!.hour * 60 + end!.minute;

  String get timeRangeLabel {
    if (start == null || end == null) return periodName;
    return '${formatHhmm(start!)}-${formatHhmm(end!)}';
  }

  /// 进行中的课进度 0..1（时间信息不足时返回 null）
  double? progressFraction(DateTime now) {
    final s = startMinutes;
    final e = endMinutes;
    if (s == null || e == null || e <= s) return null;
    final nowMinutes = now.hour * 60 + now.minute + now.second / 60.0;
    return ((nowMinutes - s) / (e - s)).clamp(0.0, 1.0);
  }
}

/// 中控看板的一帧数据：每秒由缓存的模型对象重算，零 IO
class CockpitSnapshot {
  final DateTime now;
  final bool holidayMode;
  final bool examMode;
  final bool coursesOnline;
  final bool libraryLoggedIn;
  final int? weekIndex;
  final List<CockpitClassSlot> slots;
  final CockpitClassSlot? ongoingClass;
  final CockpitClassSlot? nextClass;
  final List<LibzwReservation> reservations;
  final ExamInfo? ongoingExam;
  final ExamInfo? upcomingExam;

  CockpitSnapshot({
    required this.now,
    required this.holidayMode,
    required this.examMode,
    required this.coursesOnline,
    required this.libraryLoggedIn,
    required this.weekIndex,
    required this.slots,
    required this.ongoingClass,
    required this.nextClass,
    required this.reservations,
    required this.ongoingExam,
    required this.upcomingExam,
  });

  bool get hasExams => ongoingExam != null || upcomingExam != null;
}

/// 读取公开课表并合并自定义课程（对齐课表页 _getMergedData）。
/// 不经过 provider.getCurriculumData()——它在假期/考试模式下返回 null。
CurriculumIntegratedData? readMergedCurriculum(BaseStoreService store) {
  final base = store.getConfig<CurriculumIntegratedData>(
    'curriculum_data',
    CurriculumIntegratedData.fromJson,
  );
  if (base == null) return null;
  final custom = store.getPref<CustomCoursesList>(
    'custom_courses_${base.currentTerm.year}_${base.currentTerm.season}',
    CustomCoursesList.fromJson,
  );
  return CurriculumIntegratedData(
    currentTerm: base.currentTerm,
    allClasses: [...base.allClasses, ...?custom?.courses],
    allPeriods: base.allPeriods,
    calendarDays: base.calendarDays,
    summerTermStartDate: base.summerTermStartDate,
  );
}

/// 今日全部课程按大节分桶，按开始时间升序（缺时间信息的排最后），并标注状态
List<CockpitClassSlot> groupTodaySlots(
  CurriculumIntegratedData merged,
  DateTime now,
) {
  final buckets = <int, List<ClassItem>>{};
  for (final item in merged.getClassesToday()) {
    buckets.putIfAbsent(item.period, () => []).add(item);
  }

  final slots = <CockpitClassSlot>[];
  for (final entry in buckets.entries) {
    final first = entry.value.first;
    slots.add(CockpitClassSlot(
      period: entry.key,
      periodName: first.periodName,
      start: first.getMinStartTime(merged.allPeriods),
      end: first.getMaxEndTime(merged.allPeriods),
      classes: entry.value,
    ));
  }

  slots.sort((a, b) {
    final am = a.startMinutes;
    final bm = b.startMinutes;
    if (am == null && bm == null) return a.period.compareTo(b.period);
    if (am == null) return 1;
    if (bm == null) return -1;
    return am.compareTo(bm);
  });

  final nowMinutes = now.hour * 60 + now.minute;
  CockpitClassSlot? next;
  for (final slot in slots) {
    final s = slot.startMinutes;
    final e = slot.endMinutes;
    if (s == null || e == null) {
      slot.status = CockpitClassStatus.unknown;
    } else if (nowMinutes >= s && nowMinutes < e) {
      slot.status = CockpitClassStatus.ongoing;
    } else if (e <= nowMinutes) {
      slot.status = CockpitClassStatus.past;
    } else {
      slot.status = CockpitClassStatus.upcoming;
      next ??= slot;
    }
  }
  if (next != null) next.status = CockpitClassStatus.next;

  return slots;
}

CockpitSnapshot buildCockpitSnapshot({
  required DateTime now,
  required CurriculumIntegratedData? merged,
  required bool coursesOnline,
  required bool holidayMode,
  required bool examMode,
  required bool libraryLoggedIn,
  required List<LibzwReservation> reservations,
  required List<ExamInfo> exams,
}) {
  final slots = (!holidayMode && !examMode && merged != null)
      ? groupTodaySlots(merged, now)
      : const <CockpitClassSlot>[];

  CockpitClassSlot? ongoing;
  CockpitClassSlot? next;
  for (final slot in slots) {
    if (slot.status == CockpitClassStatus.ongoing) ongoing = slot;
    if (slot.status == CockpitClassStatus.next) next = slot;
  }

  // 假期模式不展示考试，与首页假期问候一致
  final showExams = !holidayMode;
  return CockpitSnapshot(
    now: now,
    holidayMode: holidayMode,
    examMode: examMode,
    coursesOnline: coursesOnline,
    libraryLoggedIn: libraryLoggedIn,
    weekIndex: merged?.getWeekIndexToday(),
    slots: slots,
    ongoingClass: ongoing,
    nextClass: next,
    reservations: reservations,
    ongoingExam: showExams ? ExamHelper.getOngoingExam(exams) : null,
    upcomingExam: showExams ? ExamHelper.getUpcomingExam(exams) : null,
  );
}

String formatHhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String weekdayLabel(int weekday) =>
    const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
