import '../l10n/strings.dart';

String _two(int v) => v.toString().padLeft(2, '0');

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// `Today, 17:42`, `Yesterday, 09:15`, `28 Sep 2026, 09:15`.
String formatRelativeDate(DateTime? date, {DateTime? now}) {
  if (date == null) return tr.unknownDate;
  final d = date.toLocal();
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return tr.today(formatTime(d));
  if (diff == 1) return tr.yesterday(formatTime(d));
  return formatDate(d);
}

String formatDate(DateTime d) =>
    '${d.day} ${tr.months[d.month - 1]} ${d.year}, ${formatTime(d)}';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Short form for tight spots: `today 17:42`, `yesterday`, `28 Sep`.
String formatShortDate(DateTime? date, {DateTime? now}) {
  if (date == null) return '—';
  final d = date.toLocal();
  final n = now ?? DateTime.now();
  final diff = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return tr.todayShort(formatTime(d));
  if (diff == 1) return tr.yesterdayShort;
  return '${d.day} ${tr.months[d.month - 1]}';
}
