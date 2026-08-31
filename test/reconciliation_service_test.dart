import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/services/reconciliation_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late SessionRepository sessions;

  setUp(() async {
    db = await AppDatabase.openInMemory();
    sessions = SessionRepository(db);
  });

  tearDown(() async {
    await db.db.close();
  });

  const received =
      'You have received Birr 150.00 from ABEBE KEBEDE (0911***234). '
      'Your Telebirr account balance is Birr 2,450.00. '
      'Transaction ID: 881234567890. Thank you for using telebirr!';
  const receivedLater =
      'You have received Birr 75.00 from Sara Tesfaye (09** ***234). '
      'Your Telebirr account balance is Birr 2,525.00. '
      'Transaction ID: 991234567890. Thank you for using telebirr!';

  test('inserts messages the live path missed, skips known/dirty ones',
      () async {
    final session = await sessions.startSession(nowMs: 1000);
    // The live path already stored the first payment.
    await PaymentRepository(db).insertTelebirrPaymentIfMissing(Payment(
      transactionId: '881234567890',
      sessionId: session.id,
      method: PaymentMethod.telebirr,
      amountCents: 15000,
      smsTimestampMs: 2000,
      createdAtMs: 2000,
    ));

    final fetched = const <InboxSmsItem>[
      // Known payment (duplicate) — must be ignored.
      InboxSmsItem(address: '127', body: received, dateMs: 2000),
      // Missed payment — must be inserted.
      InboxSmsItem(address: '127', body: receivedLater, dateMs: 3000),
      // Foreign sender with a convincing body — must be dropped.
      InboxSmsItem(address: '0911223344', body: received, dateMs: 3100),
      // teleBirr promo, not a payment — must be dropped.
      InboxSmsItem(address: '127', body: 'Win 100 birr with telebirr!', dateMs: 3200),
    ];

    final service = ReconciliationService(db, fetchSms: (sinceMs) async {
      expect(sinceMs, 1000, reason: 'must query from session start');
      return fetched;
    });

    final inserted = await service.reconcile();
    expect(inserted, hasLength(1));
    expect(inserted.first.transactionId, '991234567890');
    expect(inserted.first.amountCents, 7500);

    final totals = await PaymentRepository(db).totalsForSession(session.id);
    expect(totals.paymentCount, 2, reason: 'pre-existing + reconciled');
  });

  test('outside a session nothing is fetched or inserted', () async {
    var fetcherCalled = false;
    final service = ReconciliationService(db, fetchSms: (sinceMs) async {
      fetcherCalled = true;
      return const [];
    });
    expect(await service.reconcile(), isEmpty);
    expect(fetcherCalled, isFalse);
  });

  test('reconcile is idempotent — running twice inserts nothing new',
      () async {
    final session = await sessions.startSession(nowMs: 1000);
    final service = ReconciliationService(db, fetchSms: (sinceMs) async {
      return const [
        InboxSmsItem(address: '127', body: received, dateMs: 2000),
      ];
    });

    expect((await service.reconcile()).length, 1);
    expect((await service.reconcile()).length, 0);

    final totals = await PaymentRepository(db).totalsForSession(session.id);
    expect(totals.paymentCount, 1);
  });
}
