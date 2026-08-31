import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/services/csv_export_service.dart';
import 'package:taxi_pay/util/csv.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('csvField', () {
    test('plain values pass through', () {
      expect(csvField('hello'), 'hello');
      expect(csvField(150), '150');
      expect(csvField(null), '');
    });

    test('commas, quotes and newlines are escaped per RFC 4180', () {
      expect(csvField('a,b'), '"a,b"');
      expect(csvField('say "hi"'), '"say ""hi"""');
      expect(csvField('line1\nline2'), '"line1\nline2"');
    });
  });

  group('buildPaymentsCsv', () {
    test('header plus one row per payment, amounts as birr decimals', () {
      final at = DateTime(2026, 8, 31, 14, 35);
      final csv = buildPaymentsCsv([
        Payment(
          transactionId: 'PP240831.1420.A12345',
          sessionId: 1,
          method: PaymentMethod.telebirr,
          amountCents: 15000,
          payerName: 'Abebe Kebede "Baba"',
          payerPhone: '09** ***234',
          balanceAfterCents: 250000,
          smsTimestampMs: at.millisecondsSinceEpoch,
          createdAtMs: at.millisecondsSinceEpoch,
        ),
        Payment(
          transactionId: 'cash:1-abc',
          sessionId: 1,
          method: PaymentMethod.cash,
          amountCents: 7500,
          smsTimestampMs: at.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
          createdAtMs: at.millisecondsSinceEpoch,
        ),
      ]);

      final lines = csv.trimRight().split('\n');
      expect(lines.length, 3);
      expect(
        lines[0],
        'Date,Time,Method,Amount (ETB),Transaction ID,'
        'Payer name,Payer phone,Balance after (ETB)',
      );
      // Quoted because the payer name contains quotes/commas.
      expect(lines[1],
          '2026-08-31,14:35,teleBirr,150.00,PP240831.1420.A12345,'
          '"Abebe Kebede ""Baba""",09** ***234,2500.00');
      expect(lines[2], '2026-08-31,14:40,Cash,75.00,cash:1-abc,,,');
    });
  });

  group('CsvExportService', () {
    late AppDatabase app;
    late SessionRepository sessions;
    late PaymentRepository payments;

    setUp(() async {
      app = await AppDatabase.openInMemory();
      sessions = SessionRepository(app);
      payments = PaymentRepository(app);
    });

    tearDown(() => app.db.close());

    test('exports the window to a file (BOM included) and reports the count',
        () async {
      final session = await sessions.startSession();
      final day = DateTime(2026, 8, 30, 9);
      for (var i = 0; i < 3; i++) {
        final at = day.add(Duration(hours: i));
        await payments.insertTelebirrPaymentIfMissing(Payment(
          transactionId: 'TX$i',
          sessionId: session.id,
          method: PaymentMethod.telebirr,
          amountCents: 1000 * (i + 1),
          smsTimestampMs: at.millisecondsSinceEpoch,
          createdAtMs: at.millisecondsSinceEpoch,
        ));
      }

      final tmp = await Directory.systemTemp.createTemp('csv_test');
      final shared = <File>[];
      final exporter = CsvExportService(
        payments,
        onShareFile: shared.add,
        cacheDir: () async => tmp,
      );

      final result = await exporter.exportRange(
        from: DateTime(2026, 8, 30),
        to: DateTime(2026, 8, 31),
      );

      expect(result.isEmpty, false);
      expect(result.paymentCount, 3);
      expect(shared.length, 1);
      // BOM as raw bytes — readAsString() strips it, but the bytes on disk
      // are what Excel (and any share target) actually sees.
      final bytes = await shared.first.readAsBytes();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF],
          reason: 'UTF-8 BOM keeps Excel happy with Amharic text');
      final contents = await shared.first.readAsString();
      expect(contents.contains('TX1'), true);
      expect(shared.first.path, contains('taxi-pay_20260830_20260831'));
    });

    test('empty window exports nothing and shares nothing', () async {
      final exporter = CsvExportService(
        payments,
        onShareFile: (_) => fail('should not share'),
        cacheDir: () async => Directory.systemTemp,
      );
      final result = await exporter.exportRange(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 2),
      );
      expect(result.isEmpty, true);
      expect(result.paymentCount, isNull);
    });
  });
}
