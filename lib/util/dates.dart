import 'package:intl/intl.dart';

final DateFormat _clock = DateFormat('HH:mm');
final DateFormat _dayTime = DateFormat('EEE, MMM d · HH:mm');
final DateFormat _day = DateFormat('EEE, MMM d');

/// `14:35` — payment times on the live list.
String formatClock(int ms) =>
    _clock.format(DateTime.fromMillisecondsSinceEpoch(ms));

/// `Mon, Aug 31 · 14:35` — session start times.
String formatDayTime(int ms) =>
    _dayTime.format(DateTime.fromMillisecondsSinceEpoch(ms));

/// `Mon, Aug 31` — dashboard labels.
String formatDay(int ms) =>
    _day.format(DateTime.fromMillisecondsSinceEpoch(ms));

/// `2h 14m` / `48m` / `45s` — session durations.
String formatDuration(int startMs, int endMs) {
  final s = (endMs - startMs) ~/ 1000;
  if (s < 60) return '${s}s';
  final m = s ~/ 60;
  if (m < 60) return '${m}m';
  return '${m ~/ 60}h ${m % 60}m';
}
