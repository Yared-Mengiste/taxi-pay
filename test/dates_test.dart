import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taxi_pay/util/dates.dart';

void main() {
  setUpAll(() async {
    // Same call main() makes before runApp — without it, DateFormat with
    // 'am' throws on first use.
    await initializeDateFormatting();
  });
  group('startOfDay/Week/Month', () {
    test('startOfWeek anchors to Monday', () {
      final wednesday = DateTime(2026, 8, 19); // a Wednesday
      final monday = DateTime(2026, 8, 17);
      expect(startOfWeek(wednesday), monday);
      expect(startOfWeek(monday), monday);
      final sunday = DateTime(2026, 8, 23);
      expect(startOfWeek(sunday), monday);
    });

    test('startOfMonth drops day and time', () {
      final d = DateTime(2026, 8, 31, 23, 59);
      expect(startOfMonth(d), DateTime(2026, 8));
    });

    test('startOfDay drops time', () {
      final d = DateTime(2026, 8, 31, 14, 30);
      expect(startOfDay(d), DateTime(2026, 8, 31));
    });
  });

  group('addMonths', () {
    test('positive', () {
      expect(addMonths(DateTime(2026, 1), 7), DateTime(2026, 8));
      expect(addMonths(DateTime(2026, 11), 2), DateTime(2027, 1));
    });

    test('negative across year boundary', () {
      expect(addMonths(DateTime(2026, 8), -11), DateTime(2025, 9));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
    });

    test('day overflow clamps to month end', () {
      // Called on month starts in this app, but the invariant matters:
      // the result must stay a valid date within the target month.
      final r = addMonths(DateTime(2026, 1, 31), 1);
      expect(r.year, 2026);
      expect(r.month, 2);
    });

    test('zero and identity', () {
      final d = DateTime(2026, 8);
      expect(addMonths(d, 0), d);
    });
  });


  group('export windows', () {
    // A Wednesday, mid-afternoon — time-of-day must not leak into windows.
    final now = DateTime(2026, 8, 19, 15, 42);
    final monday = DateTime(2026, 8, 17);

    (DateTime, DateTime) window(ExportRangePreset p) =>
        exportWindowFor(p, now);

    test('this week is Monday-anchored and 7 days wide', () {
      final (from, to) = window(ExportRangePreset.thisWeek);
      expect(from, monday);
      expect(to.difference(from).inDays, 7);
      expect(to.isAfter(now), isTrue);
    });

    test('last week is the 7 days before this one', () {
      final (from, to) = window(ExportRangePreset.lastWeek);
      expect(from, DateTime(2026, 8, 10));
      expect(to, monday);
    });

    test('this month runs from the 1st to the 1st', () {
      final (from, to) = window(ExportRangePreset.thisMonth);
      expect(from, DateTime(2026, 8, 1));
      expect(to, DateTime(2026, 9, 1));
    });

    test('last month crosses year boundaries correctly', () {
      final (from, to) =
          exportWindowFor(ExportRangePreset.lastMonth, DateTime(2027, 1, 15));
      expect(from, DateTime(2026, 12, 1));
      expect(to, DateTime(2027, 1, 1));
    });

    test('rolling windows include today and are inclusive-sized', () {
      final (from7, to7) = window(ExportRangePreset.last7Days);
      expect(to7.difference(from7).inDays, 7); // today + the 6 before it
      expect(from7, DateTime(2026, 8, 13));

      final (from30, to30) = window(ExportRangePreset.last30Days);
      expect(to30.difference(from30).inDays, 30);
    });

    test('all time starts at the epoch and ends tomorrow', () {
      final (from, to) = window(ExportRangePreset.allTime);
      expect(from, DateTime.fromMillisecondsSinceEpoch(0));
      expect(to, DateTime(2026, 8, 20));
    });
  });

  group('localized labels', () {
    final monday = DateTime(2026, 8, 31); // a Monday
    final august = DateTime(2026, 8, 1);

    test('weekday labels localize to Amharic', () {
      expect(weekdayLabel(monday, 'am'), 'ሰኞ');
      expect(weekdayLabel(monday, 'en'), 'Mon');
      // null locale = intl default (en in this test zone).
      expect(weekdayLabel(monday, null), 'Mon');
    });

    test('month labels localize to Amharic', () {
      expect(monthLabel(august, 'am'), 'ኦገስ');
      expect(monthLabel(august, 'en'), 'Aug');
    });

    test('day+time labels localize', () {
      final at = DateTime(2026, 8, 31, 14, 35);
      final am = formatDayTime(at.millisecondsSinceEpoch, locale: 'am');
      expect(am, contains('ሰኞ'));
      expect(am, contains('14:35')); // clock digits stay locale-neutral
    });
  });
}
