import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/expense_repository.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/expense.dart';
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
  late ExpenseRepository expenses;
  late DashboardProvider dashboard;

  setUp(() async {
    app = await AppDatabase.openInMemory();
    sessions = SessionRepository(app);
    payments = PaymentRepository(app);
    expenses = ExpenseRepository(app);
    dashboard = DashboardProvider(
      payments: payments,
      expenses: expenses,
      sessions: sessions,
    );
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
    expect(dashboard.expenseTotalCents, 0);
    expect(dashboard.netCents, 0);
  });

  test('expenses in the window subtract from net', () async {
    final now = DateTime.now();
    final session = await sessions.startSession();
    await payments.insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: session.id,
      method: PaymentMethod.telebirr,
      amountCents: 30000,
      smsTimestampMs: now.millisecondsSinceEpoch,
      createdAtMs: now.millisecondsSinceEpoch,
    ));
    await sessions.stopSession();

    // Fuel from 8 days ago (outside the window) and today's other
    // expense — only today's 5000 is in the last-7-days window.
    final session2 = await sessions.startSession();
    await expenses.addExpense(
      sessionId: session2.id,
      amountCents: 12000,
      category: ExpenseCategory.fuel,
      note: 'full tank',
      timestampMs: now
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch,
    );
    await expenses.addExpense(
      sessionId: session2.id,
      amountCents: 5000,
      category: ExpenseCategory.other,
      timestampMs: now.millisecondsSinceEpoch,
    );
    await sessions.stopSession();

    await dashboard.reload();

    expect(dashboard.totalCents, 30000);
    expect(dashboard.expenseTotalCents, 5000);
    expect(dashboard.netCents, 25000);
  });

  test('past sessions list: newest first, with expenses and net', () async {
    final now = DateTime.now();
    final s1 = await sessions.startSession(
        nowMs: now.subtract(const Duration(days: 2)).millisecondsSinceEpoch);
    await payments.insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: s1.id,
      method: PaymentMethod.telebirr,
      amountCents: 20000,
      smsTimestampMs: s1.startedAtMs + 1000,
      createdAtMs: s1.startedAtMs + 1000,
    ));
    await payments.addCashPayment(
        sessionId: s1.id, amountCents: 5000, timestampMs: s1.startedAtMs + 2000);
    await expenses.addExpense(
      sessionId: s1.id,
      amountCents: 3000,
      category: ExpenseCategory.fuel,
      timestampMs: s1.startedAtMs + 3000,
    );
    await sessions.stopSession(nowMs: s1.startedAtMs + 4000);

    final s2 = await sessions.startSession(
        nowMs: now.subtract(const Duration(days: 1)).millisecondsSinceEpoch);
    await payments.addCashPayment(
        sessionId: s2.id, amountCents: 7000, timestampMs: s2.startedAtMs + 1000);
    await sessions.stopSession(nowMs: s2.startedAtMs + 2000);

    // An *active* session exists too — it must not appear in history.
    await sessions.startSession(nowMs: now.millisecondsSinceEpoch);

    await dashboard.reload();

    expect(dashboard.sessions, hasLength(2));
    // Newest first: yesterday's 7000 cash-only session.
    expect(dashboard.sessions.first.session.id, s2.id);
    expect(dashboard.sessions.first.totalCents, 7000);
    expect(dashboard.sessions.first.paymentCount, 1);
    expect(dashboard.sessions.first.expenseTotalCents, 0);
    expect(dashboard.sessions.first.netCents, 7000);
    // Two days ago: 25000 gross, 3000 expenses, 22000 net.
    expect(dashboard.sessions.last.session.id, s1.id);
    expect(dashboard.sessions.last.totalCents, 25000);
    expect(dashboard.sessions.last.paymentCount, 2);
    expect(dashboard.sessions.last.expenseTotalCents, 3000);
    expect(dashboard.sessions.last.netCents, 22000);
  });

  test('loadSessionDetail returns the session payments and expenses',
      () async {
    final now = DateTime.now();
    final s = await sessions.startSession(
        nowMs: now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch);
    await payments.insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: s.id,
      method: PaymentMethod.telebirr,
      amountCents: 12000,
      smsTimestampMs: s.startedAtMs + 1000,
      createdAtMs: s.startedAtMs + 1000,
    ));
    await payments.addCashPayment(
        sessionId: s.id, amountCents: 4000, timestampMs: s.startedAtMs + 2000);
    await expenses.addExpense(
      sessionId: s.id,
      amountCents: 2500,
      category: ExpenseCategory.fuel,
      note: 'half tank',
      timestampMs: s.startedAtMs + 3000,
    );
    await sessions.stopSession(nowMs: s.startedAtMs + 4000);

    final detail = await dashboard.loadSessionDetail(s.id);

    expect(detail.payments, hasLength(2)); // newest first
    expect(detail.payments.first.amountCents, 4000);
    expect(detail.payments.first.method, PaymentMethod.cash);
    expect(detail.expenses, hasLength(1));
    expect(detail.expenses.first.note, 'half tank');
  });
}
