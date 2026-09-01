import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/services/simulation_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase app;
  late SimulationService simulation;
  late SessionRepository sessions;

  setUp(() async {
    app = await AppDatabase.openInMemory();
    simulation = SimulationService(app);
    sessions = SessionRepository(app);
  });

  tearDown(() async {
    await app.db.close();
  });

  test('a test payment runs the full capture pipeline', () async {
    final session = await sessions.startSession();

    final payment = await simulation.sendTestPayment(
      amountCents: 12000,
      payerName: 'Abebe Balcha',
      payerPhone: '09** ***234',
    );

    expect(payment, isNotNull);
    expect(payment!.amountCents, 12000);
    expect(payment.method, PaymentMethod.telebirr);
    expect(payment.sessionId, session.id);
    expect(payment.payerName, 'Abebe Balcha');
    expect(payment.payerPhone, '09** ***234');
    // The synthesized SMS carries a balance — the wallet badge's source.
    expect(payment.balanceAfterCents, isNotNull);
    // Parser-format transaction id: uppercase, alnum, teleBirr-style prefix.
    expect(payment.transactionId, matches(RegExp(r'^PP[0-9A-Z]{10}$')));

    // It really is in storage, exactly once.
    final stored = await PaymentRepository(app)
        .paymentsForSession(session.id);
    expect(stored, hasLength(1));
    expect(stored.first.transactionId, payment.transactionId);
  });

  test('empty payer fields fall back to placeholders', () async {
    await sessions.startSession();
    final payment = await simulation.sendTestPayment(amountCents: 500);
    expect(payment, isNotNull);
    expect(payment!.payerName, 'Test Payer');
    expect(payment.payerPhone, '09** ***234');
  });

  test('without a running session nothing is captured', () async {
    final payment = await simulation.sendTestPayment(amountCents: 12000);
    expect(payment, isNull);
    expect(
        await PaymentRepository(app).paymentsBetween(0, 1 << 40), isEmpty);
  });

  test('two test payments get distinct transaction ids', () async {
    await sessions.startSession();
    final a = await simulation.sendTestPayment(amountCents: 100);
    final b = await simulation.sendTestPayment(amountCents: 200);
    expect(a!.transactionId, isNot(b!.transactionId));
  });
}
