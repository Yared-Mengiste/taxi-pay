import 'package:intl/intl.dart';

/// Formatted with the widget tree's locale (see [Localizations.localeOf]),
/// e.g. `14:35` — clock times are locale-neutral digits, but the pattern
/// cache is keyed by locale anyway so any locale-specific pattern just
/// works.
final _cache = <String, DateFormat>{};

DateFormat _fmt(String pattern, String? locale) => _cache.putIfAbsent(
      '$pattern|${locale ?? 'default'}',
      () => DateFormat(pattern, locale),
    );

/// `14:35` — payment times on the live list.
String formatClock(int ms, {String? locale}) =>
    _fmt('HH:mm', locale).format(DateTime.fromMillisecondsSinceEpoch(ms));

/// `Mon, Aug 31 · 14:35` — session start times.
String formatDayTime(int ms, {String? locale}) => _fmt('EEE, MMM d · HH:mm', locale)
    .format(DateTime.fromMillisecondsSinceEpoch(ms));

/// `Mon, Aug 31` — dashboard labels.
String formatDay(int ms, {String? locale}) =>
    _fmt('EEE, MMM d', locale).format(DateTime.fromMillisecondsSinceEpoch(ms));

/// `2h 14m` / `48m` / `45s` — session durations (locale-neutral).
String formatDuration(int startMs, int endMs) {
  final s = (endMs - startMs) ~/ 1000;
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h ${m % 60}m';
}

// ---------------------------------------------------------------------------
// Calendar-window math for the dashboard. All pure DateTime arithmetic —
// trivially unit-testable, no DB or Flutter involved.
// ---------------------------------------------------------------------------

/// Midnight of the given day, local time.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Monday of `d`'s week (weeks run Mon–Sun, the convention in Ethiopia).
DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// The 1st of `d`'s month.
DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

/// Month arithmetic that never overflows day-of-month (Jan 31 + 1m = Feb 28/29).
///
/// NB: `/12` then `.floor()` (not `~/`), which truncates toward zero —
/// `(-4) ~/ 12 == 0` would happily turn Sep 2025 into Sep 2026.
DateTime addMonths(DateTime d, int n) {
  final totalMonths = d.month - 1 + n;
  return DateTime(d.year + (totalMonths / 12).floor(), totalMonths % 12 + 1);
}

/// Weekday axis labels for the daily chart: `ሰኞ` under Amharic, `Mon`
/// under English. Full-width names keep single-letter English
/// abbreviations out of a 7-bar chart.
String weekdayLabel(DateTime start, String? locale) =>
    _fmt('E', locale).format(start);

/// Month axis labels for the monthly chart: `ኦገስ` / `Aug`.
String monthLabel(DateTime start, String? locale) =>
    _fmt('MMM', locale).format(start);
