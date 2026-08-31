import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/data/sms/sms_capture.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;

  setUp(() async {
    db = await AppDatabase.openInMemory();
  });

  tearDown(() async {
    await db.db.close();
  });

  const validBody =
      'You have received Birr 150.00 from ABEBE KEBEDE (0911***234). '
      'Your Telebirr account balance is Birr 2,450.00. '
      'Transaction ID: 881234567890. Thank you for using telebirr!';

  test('telebirr sender + active session + valid body -> row inserted',
      () async {
    final s = await SessionRepository(db).startSession(nowMs: 1000);
    final p = await captureSmsMessage(db,
        address: '127', body: validBody, timestampMs: 2000);
    expect(p, isNotNull);
    expect(p!.sessionId, s.id);
    expect(p.amountCents, 15000);
  });

  test('foreign sender address is rejected before parsing (spoofing)', () async {
    await SessionRepository(db).startSession();
    // Same body, but delivered from a scammer's phone number.
    final p = await captureSmsMessage(db,
        address: '0911223344', body: validBody, timestampMs: 2000);
    expect(p, isNull);
  });

  test('messages outside an active session are not stored', () async {
    final p = await captureSmsMessage(db,
        address: '127', body: validBody, timestampMs: 2000);
    expect(p, isNull);
  });

  test('re-delivery of the same SMS is deduped', () async {
    await SessionRepository(db).startSession();
    final first = await captureSmsMessage(db,
        address: '127', body: validBody, timestampMs: 2000);
    final second = await captureSmsMessage(db,
        address: '127', body: validBody, timestampMs: 2500);
    expect(first, isNotNull);
    expect(second, isNull);
  });

  test('unparseable body from 127 is ignored', () async {
    await SessionRepository(db).startSession();
    final p = await captureSmsMessage(db,
        address: '127', body: 'Promo: win 100 birr!', timestampMs: 2000);
    expect(p, isNull);
  });
}
