import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/models/payment.dart';
import 'package:taxi_pay/services/backup_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late AppDatabase app;
  late Directory outDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('backup_test');
    outDir = await Directory.systemTemp.createTemp('backup_out');
    // A real *file-backed* database — in-memory ones have no file to copy.
    final db = await openDatabase(
      p.join(tmp.path, AppDatabase.databaseFileName),
      version: AppDatabase.schemaVersion,
      onConfigure: AppDatabase.configureDatabase,
      onCreate: (db, version) => AppDatabase.createSchema(db),
    );
    app = AppDatabase(db);
  });

  tearDown(() async {
    await app.db.close();
    await tmp.delete(recursive: true);
    await outDir.delete(recursive: true);
  });

  test('exportBackup copies the live database and shares the copy',
      () async {
    final session = await SessionRepository(app).startSession(nowMs: 1000);
    final payments = PaymentRepository(app);
    await payments.insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX1',
      sessionId: session.id,
      method: PaymentMethod.telebirr,
      amountCents: 15000,
      balanceAfterCents: 266800,
      smsTimestampMs: 2000,
      createdAtMs: 2000,
    ));

    final shared = <File>[];
    final backup = BackupService(
      app,
      cacheDir: () async => outDir,
      onShareFile: shared.add,
    );

    final file = await backup.exportBackup();

    expect(file, isNotNull);
    expect(shared, [file]);
    expect(p.basename(file!.path), startsWith('taxi-pay-backup_'));
    expect(p.extension(file.path), '.db');
    // The copy is a byte-for-byte snapshot taken after the checkpoint.
    expect(await file.readAsBytes(), await File(app.db.path).readAsBytes());

    // And it is a *working* database: opening the copy finds the data.
    final restored = await openDatabase(file.path);
    try {
      final rows =
          await restored.rawQuery('SELECT * FROM payments');
      expect(rows, hasLength(1));
      expect(rows.first['transaction_id'], 'TX1');
      expect(rows.first['balance_after_cents'], 266800);
    } finally {
      await restored.close();
    }
  });

  test('backup succeeds even when the database is completely empty',
      () async {
    final shared = <File>[];
    final backup = BackupService(
      app,
      cacheDir: () async => outDir,
      onShareFile: shared.add,
    );

    final file = await backup.exportBackup();

    expect(file, isNotNull);
    expect(shared, hasLength(1));
  });
}
