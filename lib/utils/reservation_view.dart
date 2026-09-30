import '/types/library.dart';

/// 首页卡片 / 中控看板同款口径：今明两天、未结束且尚未到期的预约，按开始时间排序
List<LibzwReservation> filterUpcomingReservations(List<LibzwReservation> list) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dayAfterTomorrow = today.add(const Duration(days: 2));
  return list
      .where((r) =>
          !r.isEnded &&
          r.begin != null &&
          r.end != null &&
          r.end!.isAfter(now) &&
          r.begin!.isBefore(dayAfterTomorrow))
      .toList()
    ..sort((a, b) => a.begin!.compareTo(b.begin!));
}

/// 状态标签：进行中 / 今天 / 明天（调用方保证 begin/end 非空）
String reservationDayLabel(LibzwReservation r) {
  final now = DateTime.now();
  if (!r.begin!.isAfter(now) && r.end!.isAfter(now)) return '进行中';
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(r.begin!.year, r.begin!.month, r.begin!.day) == today
      ? '今天'
      : '明天';
}
