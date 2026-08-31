import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/app.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/sms/sms_service.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/services/payment_feedback_service.dart';
import 'package:taxi_pay/services/settings_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PaymentFeedbackService', () {
    test('paymentCaptured fires both effects', () {
      var beeps = 0;
      var buzzes = 0;
      final service = PaymentFeedbackService(
        onBeep: () => beeps++,
        onVibrate: () => buzzes++,
      );

      service.paymentCaptured();
      service.paymentCaptured();

      expect(beeps, 2);
      expect(buzzes, 2);
    });
  });

  group('wiring', () {
    late AppDatabase app;

    setUp(() async {
      app = await AppDatabase.openInMemory();
    });

    tearDown(() async {
      await app.db.close();
    });

    testWidgets('a payment emitted on the capture stream triggers feedback',
        (tester) async {
      SharedPreferences.setMockInitialValues(const {'onboarded': true});
      final prefs = await SharedPreferences.getInstance();
      var beeps = 0;
      await tester.pumpWidget(TaxiPayApp(
        settings: SettingsService(prefs),
        app: app,
        feedback: PaymentFeedbackService(
          onBeep: () => beeps++,
          onVibrate: () {},
        ),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      // Exactly what the reconciliation path does for newly found rows.
      SmsService.instance.emitCaptured(Payment(
        transactionId: 'TX-feedback',
        sessionId: 999, // no session — feedback must not care
        method: PaymentMethod.telebirr,
        amountCents: 15000,
        smsTimestampMs: 1,
        createdAtMs: 1,
      ));
      await tester.pump();

      expect(beeps, 1);
    });
  });
}
