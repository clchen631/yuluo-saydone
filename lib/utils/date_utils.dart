/// 凌晨 boundaryHour 点为日分界
/// 例：5月14日 03:00 (boundary=4) → "今天" = "2026-05-13"
///     5月14日 05:00 (boundary=4) → "今天" = "2026-05-14"
String getTodayDate(DateTime now, int boundaryHour) {
  final effective = now.hour < boundaryHour
      ? now.subtract(const Duration(days: 1))
      : now;
  return _formatDate(effective);
}

String getTomorrowDate(DateTime now, int boundaryHour) {
  final today = DateTime.parse(getTodayDate(now, boundaryHour));
  return _formatDate(today.add(const Duration(days: 1)));
}

String getDayAfterTomorrowDate(DateTime now, int boundaryHour) {
  final today = DateTime.parse(getTodayDate(now, boundaryHour));
  return _formatDate(today.add(const Duration(days: 2)));
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
