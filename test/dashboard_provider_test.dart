import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/providers/dashboard_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase app;
  late SessionRepository sessions;
  late PaymentRepository payments;
  late DashboardProvider dashboard;

  setUp(() async {
    app = await AppDatabase.openInMemory();
    sessions = SessionRepository(app);
    payments = PaymentRepository(app);
    dashboard = DashboardProvider(payments);
  });

  tearDown(() async {
    dashboard.dispose();
    await app.db.close();
  });

  Future<void> addPayments(List<Payment> rows) async {
    final session = await sessions.startSession();
    for (final p in rows) {
      await payments.insertTelebirrPaymentIfMissing(Payment(
        transactionId: p.transactionId,
        sessionId: session.id,
        method: p.method,
        amountCents: p.amountCents,
        smsTimestampMs: p.smsTimestampMs,
        createdAtMs: p.smsTimestampMs,
      ));
    }
    await sessions.stopSession();
  }

  Payment telebirr(String txId, int cents, DateTime at) => Payment(
        transactionId: txId,
        sessionId: 0,
        method: PaymentMethod.telebirr,
        amountCents: cents,
        smsTimestampMs: at.millisecondsSinceEpoch,
        createdAtMs: at.millisecondsSinceEpoch,
      );

  Payment cash(String txId, int cents, DateTime at) => Payment(
        transactionId: txId,
        sessionId: 0,
        method: PaymentMethod.cash,
        amountCents: cents,
        smsTimestampMs: at.millisecondsSinceEpoch,
        createdAtMs: at.millisecondsSinceEpoch,
      );

  test('daily window: 7 zero-filled buckets, today sums both methods',
      () async {
    final now = DateTime.now();
    await addPayments([
      telebirr('TX1', 10000, now), // today
      telebirr('TX2', 25000, DateTime(now.year, now.month, now.day - 3, 10)),
      cash('C1', 5000, now), // today, cash
    ]);

    await dashboard.reload();

    expect(dashboard.buckets.length, 7);
    expect(dashboard.totalCents, 40000);
    expect(dashboard.paymentCount, 3);
    expect(dashboard.buckets.last.totalCents, 15000); // today
    expect(dashboard.buckets.last.paymentCount, 2);
    expect(dashboard.buckets[3].totalCents, 25000); // 3 days ago
    expect(dashboard.buckets[0].isEmpty, true); // oldest day zero-filled
    expect(dashboard.byMethod[PaymentMethod.telebirr]!.totalCents, 35000);
    expect(dashboard.byMethod[PaymentMethod.cash]!.totalCents, 5000);
  });

  test('weekly window: 8 Monday-anchored buckets', () async {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    await addPayments([
      telebirr('TX1', 10000, thisMonday.add(const Duration(days: 2))),
      telebirr('TX2', 20000, thisMonday.add(const Duration(days: 5))),
      telebirr('TX3', 40000,
          thisMonday.subtract(const Duration(days: 10))), // 2 weeks ago
    ]);

    await dashboard.setPeriod(DashboardPeriod.week);

    expect(dashboard.buckets.length, 8);
    expect(dashboard.totalCents, 70000);
    expect(dashboard.buckets.last.start, thisMonday);
    expect(dashboard.buckets.last.totalCents, 30000); // both this week
    // 10 days before this Monday = the week that started 14 days ago.
    expect(dashboard.buckets[5].totalCents, 40000);
    expect(dashboard.buckets[6].totalCents, 0); // last week, no payments
    // Buckets are 7 days apart.
    expect(dashboard.buckets[1].start
        .difference(dashboard.buckets[0].start)
        .inDays, 7);
  });

  test('monthly window: 12 buckets keyed by first of month', () async {
    final now = DateTime.now();
    await addPayments([
      telebirr('TX1', 10000, DateTime(now.year, now.month, 15)),
      telebirr('TX2', 30000, DateTime(now.year, now.month - 1, 2)),
    ]);

    await dashboard.setPeriod(DashboardPeriod.month);

    expect(dashboard.buckets.length, 12);
    expect(dashboard.buckets.last.start.day, 1);
    expect(dashboard.buckets.last.totalCents, 10000);
    expect(dashboard.buckets[10].totalCents, 30000);
  });

  test('payments older than the window are excluded', () async {
    final now = DateTime.now();
    await addPayments([
      telebirr('OLD', 99999, DateTime(now.year, now.month, now.day - 30)),
      telebirr('NEW', 10000, now),
    ]);

    await dashboard.reload();

    expect(dashboard.totalCents, 10000);
    expect(dashboard.paymentCount, 1);
  });

  test('empty database yields zero revenue and empty-state flag', () async {
    await dashboard.reload();
    expect(dashboard.hasRevenue, false);
    expect(dashboard.buckets.length, 7);
    expect(dashboard.totalCents, 0);
  });
}
