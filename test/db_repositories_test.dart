import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
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

    test('paymentsBetween is [from, to) over sms timestamps', () async {
      final s = await sessions.startSession();
      for (final ts in [100, 200, 300]) {
        await payments.addCashPayment(
            sessionId: s.id, amountCents: 1000, timestampMs: ts);
      }
      final inRange = await payments.paymentsBetween(100, 300);
      expect(inRange.map((p) => p.smsTimestampMs), [100, 200]);
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
