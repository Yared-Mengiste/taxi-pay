import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/expense_repository.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/expense.dart';
import 'package:taxi_pay/models/payment.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late SessionRepository sessions;
  late PaymentRepository payments;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    sessions = SessionRepository(db);
    payments = PaymentRepository(db);
  });

  tearDown(() async {
    await db.db.close();
  });

  group('SessionRepository', () {
    test('start is idempotent — no two active sessions', () async {
      final a = await sessions.startSession(nowMs: 1000);
      final b = await sessions.startSession(nowMs: 2000);
      expect(b.id, a.id);

      final active = await sessions.activeSession();
      expect(active, isNotNull);
      expect(active!.startedAtMs, 1000);
    });

    test('stop closes the active session and clears activeSession()',
        () async {
      await sessions.startSession(nowMs: 1000);
      await sessions.stopSession(nowMs: 5000);
      expect(await sessions.activeSession(), isNull);

      final done = await sessions.recentSessions();
      expect(done, hasLength(1));
      expect(done.first.session.startedAtMs, 1000);
      expect(done.first.session.endedAtMs, 5000);
      expect(done.first.expenseTotalCents, 0);
      expect(done.first.netCents, 0);
    });

    test('recentSessions aggregates payments and expenses per session',
        () async {
      final s1 = await sessions.startSession(nowMs: 1000);
      await payments.addCashPayment(
          sessionId: s1.id, amountCents: 5000, timestampMs: 1500);
      await ExpenseRepository(db).addExpense(
        sessionId: s1.id,
        amountCents: 2000,
        category: ExpenseCategory.fuel,
        timestampMs: 1600,
      );
      await sessions.stopSession(nowMs: 2000);

      final s2 = await sessions.startSession(nowMs: 3000);
      await payments.addCashPayment(
          sessionId: s2.id, amountCents: 7000, timestampMs: 3500);
      await sessions.stopSession(nowMs: 4000);

      final done = await sessions.recentSessions();
      expect(done, hasLength(2));
      // Newest first.
      expect(done.first.session.id, s2.id);
      expect(done.first.totalCents, 7000);
      expect(done.first.paymentCount, 1);
      expect(done.first.expenseTotalCents, 0);
      expect(done.first.netCents, 7000);
      expect(done.last.session.id, s1.id);
      expect(done.last.totalCents, 5000);
      expect(done.last.expenseTotalCents, 2000);
      expect(done.last.netCents, 3000);
    });

    test('active session state is durable — a new repository sees it too',
        () async {
      await sessions.startSession(nowMs: 1000);
      // Simulates the app being killed: a fresh repository over the same DB.
      final fresh = SessionRepository(db);
      expect(await fresh.activeSession(), isNotNull);
    });
  });

  group('PaymentRepository', () {
    test('duplicate transaction ids are silently dropped', () async {
      final s = await sessions.startSession(nowMs: 1000);
      final insertedFirst = await payments.insertTelebirrPaymentIfMissing(
        Payment(
          transactionId: 'TX123',
          sessionId: s.id,
          method: PaymentMethod.telebirr,
          amountCents: 15000,
          smsTimestampMs: 2000,
          createdAtMs: 2001,
        ),
      );
      final insertedAgain = await payments.insertTelebirrPaymentIfMissing(
        Payment(
          transactionId: 'TX123',
          sessionId: s.id,
          method: PaymentMethod.telebirr,
          amountCents: 15000,
          smsTimestampMs: 2000,
          createdAtMs: 2500,
        ),
      );
      expect(insertedFirst, isTrue);
      expect(insertedAgain, isFalse);

      final totals = await payments.totalsForSession(s.id);
      expect(totals.paymentCount, 1);
      expect(totals.totalCents, 15000);
    });

    test('cash entries get unique transaction ids and count toward totals',
        () async {
      final s = await sessions.startSession(nowMs: 1000);
      await payments.addCashPayment(
          sessionId: s.id, amountCents: 5000, timestampMs: 1500);
      await payments.addCashPayment(
          sessionId: s.id, amountCents: 2500, timestampMs: 1600);

      final forSession = await payments.paymentsForSession(s.id);
      expect(forSession, hasLength(2));
      expect(forSession.map((p) => p.transactionId).toSet().length, 2);
      expect(forSession.every((p) => p.method == PaymentMethod.cash), isTrue);
    });

    test('payments require an existing session (foreign key)', () async {
      expect(
        () => payments.insertTelebirrPaymentIfMissing(Payment(
          transactionId: 'TX1',
          sessionId: 999,
          method: PaymentMethod.telebirr,
          amountCents: 100,
          smsTimestampMs: 1,
          createdAtMs: 1,
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('non-positive amounts are rejected by the schema', () async {
      final s = await sessions.startSession();
      expect(
        () => payments.addCashPayment(sessionId: s.id, amountCents: 0),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('latestTelebirrBalanceCents returns the newest teleBirr balance',
        () async {
      final s = await sessions.startSession(nowMs: 1000);
      expect(await payments.latestTelebirrBalanceCents(), isNull);

      Future<void> tx(String id, int cents, int balance, int at) =>
          payments.insertTelebirrPaymentIfMissing(Payment(
            transactionId: id,
            sessionId: s.id,
            method: PaymentMethod.telebirr,
            amountCents: cents,
            balanceAfterCents: balance,
            smsTimestampMs: at,
            createdAtMs: at,
          ));

      await tx('TX1', 15000, 245000, 2000);
      await tx('TX2', 5000, 250000, 3000);
      // Cash rows never carry a balance and must not be considered.
      await payments.addCashPayment(
          sessionId: s.id, amountCents: 1000, timestampMs: 4000);

      expect(await payments.latestTelebirrBalanceCents(), 250000);
    });

    test('paymentsBetween is [from, to) over sms timestamps', () async {
      final s = await sessions.startSession();
      for (final ts in [100, 200, 300]) {
        await payments.addCashPayment(
            sessionId: s.id, amountCents: 1000, timestampMs: ts);
      }
      final inRange = await payments.paymentsBetween(100, 300);
      expect(inRange.map((p) => p.smsTimestampMs), [100, 200]);
    });

    test('cash edit/delete only ever touch cash rows', () async {
      final s = await sessions.startSession(nowMs: 1000);
      await payments.addCashPayment(
          sessionId: s.id, amountCents: 5000, timestampMs: 1500);
      await payments.insertTelebirrPaymentIfMissing(Payment(
        transactionId: 'TX9',
        sessionId: s.id,
        method: PaymentMethod.telebirr,
        amountCents: 12000,
        smsTimestampMs: 1600,
        createdAtMs: 1600,
      ));

      Future<int> idOf(PaymentMethod method) async => (await payments
              .paymentsForSession(s.id))
          .firstWhere((p) => p.method == method)
          .id!;
      final cashRowId = await idOf(PaymentMethod.cash);
      final txRowId = await idOf(PaymentMethod.telebirr);

      // Editing a cash entry works and totals follow.
      expect(
        await payments.updateCashAmount(
            paymentId: cashRowId, amountCents: 4200),
        isTrue,
      );
      final afterEdit = await payments.totalsForSession(s.id);
      expect(afterEdit.totalCents, 12000 + 4200);

      // The same calls aimed at a teleBirr row are refused, and the row
      // survives untouched — receipts are immutable at the query level.
      expect(
        await payments.updateCashAmount(
            paymentId: txRowId, amountCents: 1),
        isFalse,
      );
      expect(await payments.deleteCashPayment(paymentId: txRowId), isFalse);
      final afterAttack = await payments.paymentsForSession(s.id);
      expect(afterAttack, hasLength(2));
      expect(
        afterAttack
            .firstWhere((p) => p.method == PaymentMethod.telebirr)
            .amountCents,
        12000,
      );

      // Deleting the cash entry removes exactly it.
      expect(await payments.deleteCashPayment(paymentId: cashRowId), isTrue);
      expect(await payments.deleteCashPayment(paymentId: cashRowId), isFalse);
      final afterDelete = await payments.totalsForSession(s.id);
      expect(afterDelete.paymentCount, 1);
      expect(afterDelete.totalCents, 12000);
    });

    test('dailyTotals buckets by local calendar day', () async {
      final s = await sessions.startSession();
      final day1 = DateTime(2026, 8, 30, 10, 30).millisecondsSinceEpoch;
      final day1Late = DateTime(2026, 8, 30, 23, 59).millisecondsSinceEpoch;
      final day2 = DateTime(2026, 8, 31, 0, 1).millisecondsSinceEpoch;
      for (final ts in [day1, day1Late, day2]) {
        await payments.addCashPayment(
            sessionId: s.id, amountCents: 1000, timestampMs: ts);
      }

      final totals = await payments.dailyTotals(
        DateTime(2026, 8, 30).millisecondsSinceEpoch,
        DateTime(2026, 9, 1).millisecondsSinceEpoch,
      );
      expect(totals['2026-08-30']!.paymentCount, 2);
      expect(totals['2026-08-30']!.totalCents, 2000);
      expect(totals['2026-08-31']!.paymentCount, 1);
    });
  });
}
