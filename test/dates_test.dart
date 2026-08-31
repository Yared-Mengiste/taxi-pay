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
