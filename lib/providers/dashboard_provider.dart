import 'package:flutter/foundation.dart';

import '../data/db/expense_repository.dart';
import '../data/db/payment_repository.dart';
import '../models/payment.dart';
import '../util/dates.dart';

/// What one bar on the dashboard chart represents.
enum DashboardPeriod {
  /// Last 7 days, one bar per day.
  day,

  /// Last 8 weeks (Mon-anchored), one bar per week.
  week,

  /// Last 12 months, one bar per month.
  month;
}

/// One chart bar: the bucket's start day, its revenue and payment count.
/// Zero-filled buckets are included — an empty day is still a day.
class RevenueBucket {
  const RevenueBucket({
    required this.start,
    required this.totalCents,
    required this.paymentCount,
  });

  /// Local-midnight start of the bucket (day / Monday / 1st of month).
  final DateTime start;
  final int totalCents;
  final int paymentCount;

  bool get isEmpty => paymentCount == 0;
}

/// Aggregated revenue for the selected window. The DB does what SQL is good
/// at (one `GROUP BY day` query); Dart does what Dart is good at (calendar
/// math and zero-filling the chart buckets).
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required PaymentRepository payments,
    required ExpenseRepository expenses,
  })  : _paymentsRepo = payments,
        _expensesRepo = expenses;

  final PaymentRepository _paymentsRepo;
  final ExpenseRepository _expensesRepo;

  DashboardPeriod _period = DashboardPeriod.day;
  List<RevenueBucket> _buckets = const [];
  Map<PaymentMethod, BucketTotal> _byMethod = const {};
  int _expenseTotalCents = 0;
  bool _loading = false;

  DashboardPeriod get period => _period;

  /// Oldest bucket first — left-to-right on the chart.
  List<RevenueBucket> get buckets => List.unmodifiable(_buckets);

  Map<PaymentMethod, BucketTotal> get byMethod => _byMethod;

  bool get loading => _loading;

  /// Window expense total (fuel and other) — the other half of the story
  /// the gross total tells.
  int get expenseTotalCents => _expenseTotalCents;

  /// Gross minus expenses: what the window actually earned the driver.
  int get netCents => totalCents - _expenseTotalCents;

  int get totalCents =>
      _buckets.fold(0, (sum, b) => sum + b.totalCents);

  int get paymentCount =>
      _buckets.fold(0, (sum, b) => sum + b.paymentCount);

  /// Total in the window divided by the number of buckets — "per day" /
  /// "per week" / "per month" depending on the period.
  int get averagePerBucketCents =>
      _buckets.isEmpty ? 0 : (totalCents / _buckets.length).round();

  bool get hasRevenue => totalCents > 0;

  /// The window currently on screen — what an "Export CSV" should contain.
  /// (Recomputed rather than cached: pure, cheap, always in sync with
  /// [period] even if reload hasn't finished.)
  DateTime get windowFrom =>
      _bucketStarts(DateTime.now()).first;
  DateTime get windowTo => _endOf(DateTime.now());

  Future<void> setPeriod(DashboardPeriod period) {
    if (period == _period) return Future.value();
    _period = period;
    return reload();
  }

  /// Initial load — same as [reload]; named for symmetry with the other
  /// providers' `..load()` bootstrap idiom.
  Future<void> load() => reload();

  Future<void> reload() async {
    _loading = true;
    notifyListeners();

    final now = DateTime.now();
    final bucketStarts = _bucketStarts(now);
    final from = bucketStarts.first;
    final to = _endOf(now);

    // One grouped query for the whole window, then bucket in Dart.
    final daily = await _paymentsRepo.dailyTotals(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    final byMethod = await _paymentsRepo.totalsByMethod(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );
    final expenseTotal = await _expensesRepo.totalCentsBetween(
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
    );

    // Fold each local day into its containing bucket.
    final fold = <int, List<int>>{}; // bucketIndex -> [totalCents, count]
    for (var i = 0; i < bucketStarts.length; i++) {
      fold[i] = [0, 0];
    }
    for (final entry in daily.entries) {
      final day = DateTime.parse(entry.key);
      final bucket = _bucketOf(day);
      final index = bucketStarts.indexOf(bucket);
      if (index < 0) continue; // outside window (paranoia; can't happen)
      fold[index]![0] += entry.value.totalCents;
      fold[index]![1] += entry.value.paymentCount;
    }

    _buckets = [
      for (var i = 0; i < bucketStarts.length; i++)
        RevenueBucket(
          start: bucketStarts[i],
          totalCents: fold[i]![0],
          paymentCount: fold[i]![1],
        ),
    ];
    _byMethod = byMethod;
    _expenseTotalCents = expenseTotal;
    _loading = false;
    notifyListeners();
  }

  /// The ordered bucket starts for the current period: 7 days, 8 Mondays
  /// or 12 firsts-of-month, ending with the current one.
  List<DateTime> _bucketStarts(DateTime now) => switch (_period) {
        DashboardPeriod.day => [
            for (var i = 6; i >= 0; i--)
              startOfDay(now.subtract(Duration(days: i))),
          ],
        DashboardPeriod.week => [
            for (var i = 7; i >= 0; i--) startOfWeek(now).subtract(
                Duration(days: 7 * i)),
          ],
        DashboardPeriod.month => [
            for (var i = 11; i >= 0; i--) addMonths(startOfMonth(now), -i),
          ],
      };

  /// Truncate a day to its containing bucket start.
  DateTime _bucketOf(DateTime day) => switch (_period) {
        DashboardPeriod.day => startOfDay(day),
        DashboardPeriod.week => startOfWeek(day),
        DashboardPeriod.month => startOfMonth(day),
      };

  /// Exclusive upper bound of the window.
  DateTime _endOf(DateTime now) => switch (_period) {
        DashboardPeriod.day => startOfDay(now).add(const Duration(days: 1)),
        DashboardPeriod.week =>
          startOfWeek(now).add(const Duration(days: 7)),
        DashboardPeriod.month => addMonths(startOfMonth(now), 1),
      };
}
