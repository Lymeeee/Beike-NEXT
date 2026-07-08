import '/types/courses.dart';

class ExamHelper {
  /// Returns the exam that is currently ongoing (started but not yet ended),
  /// or null if no exam is in progress.
  static ExamInfo? getOngoingExam(List<ExamInfo> exams) {
    final now = DateTime.now();
    for (final exam in exams) {
      final start = exam.getStartTime();
      final end = exam.getEndTime();
      if (start != null && end != null && now.isAfter(start) && now.isBefore(end)) {
        return exam;
      }
    }
    return null;
  }

  /// Returns the next upcoming exam (nearest future exam by start time),
  /// regardless of how many days away.
  static ExamInfo? getUpcomingExam(List<ExamInfo> exams) {
    final now = DateTime.now();
    ExamInfo? upcoming;
    DateTime? upcomingStart;
    for (final exam in exams) {
      final start = exam.getStartTime();
      if (start == null) continue;
      if (start.isAfter(now) && (upcomingStart == null || start.isBefore(upcomingStart))) {
        upcoming = exam;
        upcomingStart = start;
      }
    }
    return upcoming;
  }

  /// Returns true if all exams in the list have already ended.
  static bool allExamsEnded(List<ExamInfo> exams) {
    final now = DateTime.now();
    for (final exam in exams) {
      final end = exam.getEndTime();
      if (end != null && now.isBefore(end)) return false;
    }
    return true;
  }

  /// Exam with its precomputed start/end times for UI display.
  static ({DateTime start, DateTime end})? getTimeRange(ExamInfo exam) {
    final start = exam.getStartTime();
    final end = exam.getEndTime();
    if (start == null || end == null) return null;
    return (start: start, end: end);
  }
}
