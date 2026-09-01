import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/expense_repository.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/expense.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/providers/session_provider.dart';
import 'package:taxi_pay/services/reconciliation_service.dart';

const _testSmsBody =
    'You have received ETB 150.00 from Abebe Balcha (09** ***234). '
    'Transaction ID: 881234567890. Your current balance is ETB 500.00.';

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

  test('expenses subtract from net and survive into the shift summary',
      () async {
    await provider.load();
    await provider.start();

    await provider.addCash(amountCents: 10000);
    await provider.addExpense(
        amountCents: 6000, category: ExpenseCategory.fuel, note: 'fuel');
    await provider.addExpense(amountCents: 1500, category: ExpenseCategory.other);

    expect(provider.totalCents, 10000);
    expect(provider.expenseTotalCents, 7500);
    expect(provider.netCents, 2500);
    expect(provider.expenses, hasLength(2));
    // Newest first, same rule as payments.
    expect(provider.expenses.first.category, ExpenseCategory.other);

    await provider.stop();
    expect(provider.lastEndedExpenseTotalCents, 7500);
    expect(provider.lastEndedNetCents, 2500);
    expect(provider.lastEndedExpenses, hasLength(2));

    // A fresh reload from the DB (cold start) finds expenses too.
    await provider.load();
    expect(provider.isRunning, isFalse);
    expect(provider.expenses, isEmpty);
    expect(
      await ExpenseRepository(db)
          .totalCentsForSession(provider.lastEndedSession!.id),
      7500,
    );
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

  test('cash entries can be corrected or deleted through the provider',
      () async {
    await provider.load();
    await provider.start();
    await provider.addCash(amountCents: 5000);
    await provider.addCash(amountCents: 2500);
    final cashEntry = provider.payments.first; // newest first = the 2500
    expect(cashEntry.method, PaymentMethod.cash);

    await provider.updateCash(payment: cashEntry, amountCents: 3000);
    expect(provider.totalCents, 8000); // 5000 + corrected 3000
    expect(provider.payments.first.amountCents, 3000);

    await provider.deleteCash(payment: provider.payments.first);
    expect(provider.paymentCount, 1);
    expect(provider.totalCents, 5000);

    // And the telebirr path is a no-op even if called directly.
    await PaymentRepository(db).insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: provider.activeSession!.id,
      method: PaymentMethod.telebirr,
      amountCents: 9000,
      smsTimestampMs: 2000,
      createdAtMs: 2000,
    ));
    await provider.load();
    final telebirrEntry =
        provider.payments.firstWhere((p) => p.method == PaymentMethod.telebirr);
    await provider.updateCash(payment: telebirrEntry, amountCents: 1);
    await provider.deleteCash(payment: telebirrEntry);
    expect(provider.paymentCount, 2);
    expect(provider.totalCents, 5000 + 9000);
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

  test('method split getters separate telebirr from cash', () async {
    await provider.load();
    await provider.start();
    await provider.addCash(amountCents: 5000);
    await PaymentRepository(db).insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: provider.activeSession!.id,
      method: PaymentMethod.telebirr,
      amountCents: 9000,
      smsTimestampMs: 2000,
      createdAtMs: 2000,
    ));
    await provider.load();

    expect(provider.totalCents, 14000);
    expect(provider.telebirrTotalCents, 9000);
    expect(provider.cashTotalCents, 5000);
  });

  test('reconcile() inserts missed inbox payments exactly once', () async {
    var fetchCalls = 0;
    final reconciled = <Payment>[];
    final reconciling = SessionProvider(
      app: db,
      capturedPayments: events.stream,
      reconciliation: ReconciliationService(
        db,
        fetchSms: (sinceMs) async {
          fetchCalls++;
          return [
            InboxSmsItem(
              address: '127',
              body: _testSmsBody,
              dateMs: DateTime.now().millisecondsSinceEpoch,
            ),
          ];
        },
      ),
      onReconciledPayment: reconciled.add,
    );

    await reconciling.load();
    // Without a running session there is nothing to reconcile — the
    // inbox isn't even queried.
    expect(await reconciling.reconcile(), 0);
    expect(fetchCalls, 0);

    await reconciling.start();
    final inserted = await reconciling.reconcile();
    expect(inserted, 1);
    expect(reconciling.paymentCount, 1);
    expect(reconciling.totalCents, 15000);
    expect(reconciling.walletBalanceCents, 50000);
    expect(reconciled, hasLength(1)); // re-emitted for beep + live reload
    expect(reconciling.isReconciling, isFalse);

    // Idempotent: the same inbox message cannot be inserted twice.
    expect(await reconciling.reconcile(), 0);
    expect(reconciling.paymentCount, 1);

    reconciling.dispose();
  });
}
