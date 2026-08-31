import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/providers/session_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late StreamController<Payment> events;
  late SessionProvider provider;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    events = StreamController<Payment>.broadcast();
    provider = SessionProvider(app: db, capturedPayments: events.stream);
  });

  tearDown(() async {
    provider.dispose();
    // Let any stream-triggered reload still in flight settle before the
    // database goes away (it would otherwise hit database_closed).
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await events.close();
    await db.db.close();
  });

  test('start -> running, stop -> ended summary retained', () async {
    await provider.load();
    expect(provider.isRunning, isFalse);

    await provider.start();
    expect(provider.isRunning, isTrue);
    expect(provider.activeSession, isNotNull);

    await provider.addCash(amountCents: 5000);
    await provider.addCash(amountCents: 2500);
    expect(provider.paymentCount, 2);
    expect(provider.totalCents, 7500);

    await provider.stop();
    expect(provider.isRunning, isFalse);
    expect(provider.payments, isEmpty);
    // The just-ended session keeps its totals for the summary screen.
    expect(provider.lastEndedSession, isNotNull);
    expect(provider.lastEndedSession!.endedAtMs, isNotNull);
    expect(provider.lastEndedTotalCents, 7500);
    expect(provider.lastEndedPayments, hasLength(2));
  });

  test('captured payment stream triggers a reload', () async {
    await provider.load();
    await provider.start();

    // Simulate the SMS pipeline: row appears in the DB, event fires.
    await PaymentRepository(db).insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: provider.activeSession!.id,
      method: PaymentMethod.telebirr,
      amountCents: 15000,
      balanceAfterCents: 266800,
      smsTimestampMs: 1000,
      createdAtMs: 1000,
    ));
    events.add(Payment(
      transactionId: 'TX1',
      sessionId: provider.activeSession!.id,
      method: PaymentMethod.telebirr,
      amountCents: 15000,
      balanceAfterCents: 266800,
      smsTimestampMs: 1000,
      createdAtMs: 1000,
    ));
    // Give the broadcast listener's reload (two chained async queries) time
    // to land before asserting.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(provider.paymentCount, 1);
    expect(provider.totalCents, 15000);
    // The wallet balance rides along on every reload.
    expect(provider.walletBalanceCents, 266800);
  });

  test('cold start recovers an active session from the DB', () async {
    // A session was running when the "app died": only the DB row survives.
    final repo = SessionRepository(db);
    final s = await repo.startSession(nowMs: 1000);
    await PaymentRepository(db).addCashPayment(
        sessionId: s.id, amountCents: 1000, timestampMs: 1500);

    await provider.load();
    expect(provider.isRunning, isTrue);
    expect(provider.paymentCount, 1);
    expect(provider.totalCents, 1000);
  });

  test('start is idempotent through the provider as well', () async {
    await provider.load();
    await provider.start();
    final firstId = provider.activeSession!.id;
    await provider.start();
    expect(provider.activeSession!.id, firstId);
    expect(
        (await SessionRepository(db).recentSessions(limit: 5))
            .where((s) => s.session.isActive),
        isEmpty);
  });
}
