import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('a v1 database upgrades in place: data survives, expenses work',
      () async {
    final dir = await Directory.systemTemp.createTemp('migration_test');
    final path = p.join(dir.path, AppDatabase.databaseFileName);

    // Build exactly what the old app shipped: a version-1 database with
    // real rows in it.
    final v1 = await openDatabase(
      path,
      version: 1,
      onConfigure: AppDatabase.configureDatabase,
      onCreate: (db, version) => AppDatabase.createSchema(db, version: 1),
    );
    final oldApp = AppDatabase(v1);
    final session = await SessionRepository(oldApp).startSession(nowMs: 1000);
    await PaymentRepository(oldApp).insertTelebirrPaymentIfMissing(Payment(
      transactionId: 'TX-OLD',
      sessionId: session.id,
      method: PaymentMethod.telebirr,
      amountCents: 15000,
      balanceAfterCents: 245000,
      smsTimestampMs: 2000,
      createdAtMs: 2000,
    ));
    await v1.close();

    // The upgrade: the current app opens the same file at version 2.
    final v2 = await openDatabase(
      path,
      version: AppDatabase.schemaVersion,
      onConfigure: AppDatabase.configureDatabase,
      onUpgrade: AppDatabase.upgradeSchema,
    );
    final app = AppDatabase(v2);

    // Old rows survived untouched.
    final payments = await PaymentRepository(app).paymentsForSession(session.id);
    expect(payments, hasLength(1));
    expect(payments.first.transactionId, 'TX-OLD');
    expect(payments.first.balanceAfterCents, 245000);

    // The new table exists and enforces its rules.
    final expenses = ExpenseRepository(app);
    final fuel = await expenses.addExpense(
      sessionId: session.id,
      amountCents: 8000,
      category: ExpenseCategory.fuel,
      note: 'half a tank',
      timestampMs: 3000,
    );
    expect(fuel.id, isNotNull);
    expect(
      await expenses.totalCentsForSession(session.id),
      8000,
    );
    expect(
      () => expenses.addExpense(
        sessionId: session.id,
        amountCents: 0,
        category: ExpenseCategory.other,
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => expenses.addExpense(
        sessionId: 999,
        amountCents: 100,
        category: ExpenseCategory.other,
      ),
      throwsA(isA<DatabaseException>()),
      reason: 'expenses require an existing session (foreign key)',
    );

    // And the upgrade is idempotent at the open level: opening again at
    // the same version runs no migration and keeps everything.
    await v2.close();
    final again = await openDatabase(
      path,
      version: AppDatabase.schemaVersion,
      onConfigure: AppDatabase.configureDatabase,
      onUpgrade: AppDatabase.upgradeSchema,
    );
    expect(
      await ExpenseRepository(AppDatabase(again))
          .totalCentsForSession(session.id),
      8000,
    );
    await again.close();

    await dir.delete(recursive: true);
  });

  test('fresh installs get the v2 schema directly', () async {
    final app = await AppDatabase.openInMemory();
    addTearDown(() => app.db.close());

    // The expenses table exists on a brand-new database…
    final rows = await app.db
        .rawQuery("SELECT name FROM sqlite_master WHERE name = 'expenses'");
    expect(rows, hasLength(1));
    // …and the schema version is what we expect.
    expect(await app.db.getVersion(), AppDatabase.schemaVersion);
  });
}
