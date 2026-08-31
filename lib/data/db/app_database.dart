import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the SQLite schema and opens the database.
///
/// Instances are cheap wrappers; the important rule is that **every isolate
/// must open its own connection** (you cannot pass a `Database` across an
/// isolate boundary). The main UI isolate, the SMS background isolate and the
/// WorkManager isolate each call [openDefault] once. SQLite handles the
/// concurrent file access; the `busy_timeout` pragma below keeps rare
/// write-overlaps from failing.
class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const databaseFileName = 'taxi_pay.db';

  /// Bump when the schema changes, and add the matching step to
  /// [upgradeSchema] (and [createSchema]).
  static const schemaVersion = 2;

  static AppDatabase? _cachedDefault;

  /// Opens (and caches for this isolate) the app database.
  static Future<AppDatabase> openDefault() async {
    if (_cachedDefault != null) return _cachedDefault!;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, databaseFileName),
      version: schemaVersion,
      onConfigure: configureDatabase,
      onCreate: (db, version) => createSchema(db),
      onUpgrade: upgradeSchema,
    );
    return _cachedDefault = AppDatabase(db);
  }

  /// For tests: same settings over an in-memory database.
  static Future<AppDatabase> openInMemory() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: schemaVersion,
      onConfigure: configureDatabase,
      onCreate: (db, version) => createSchema(db),
      onUpgrade: upgradeSchema,
    );
    return AppDatabase(db);
  }

  static Future<void> configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // `PRAGMA busy_timeout = N` returns the new value as a result row. On
    // Android, db.execute (SQLiteDatabase.execSQL) rejects statements that
    // return rows, so this must go through rawQuery. (execute works on
    // iOS/desktop, so the mismatch only shows up on Android.)
    await db.rawQuery('PRAGMA busy_timeout = 5000');
  }

  /// Creates the full schema at [version] — every fresh install runs this
  /// at [schemaVersion]; the migration test also uses it to *build* an old
  /// database, by passing an older version.
  static Future<void> createSchema(Database db,
      {int version = schemaVersion}) async {
    // --- v1: sessions + payments -------------------------------------
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at_ms INTEGER NOT NULL,
        ended_at_ms INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id TEXT NOT NULL UNIQUE,
        session_id INTEGER NOT NULL REFERENCES sessions(id),
        method TEXT NOT NULL CHECK (method IN ('telebirr', 'cash')),
        amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
        payer_name TEXT,
        payer_phone TEXT,
        balance_after_cents INTEGER,
        sms_timestamp_ms INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_payments_session ON payments(session_id)');
    await db.execute(
        'CREATE INDEX idx_payments_ts ON payments(sms_timestamp_ms)');

    // --- v2: expenses (fuel etc.) ------------------------------------
    if (version >= 2) await _createExpenseTable(db);
  }

  /// Step-wise upgrades for existing installs. Each `if (from < n)` block
  /// must be idempotent *in sequence* (a v1 database jumping straight to
  /// v3 runs both the v2 and v3 steps).
  static Future<void> upgradeSchema(Database db, int from, int to) async {
    if (from < 2) await _createExpenseTable(db);
  }

  static Future<void> _createExpenseTable(Database db) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id),
        category TEXT NOT NULL CHECK (category IN ('fuel', 'other')),
        amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
        note TEXT,
        expense_timestamp_ms INTEGER NOT NULL,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_expenses_session ON expenses(session_id)');
    await db.execute(
        'CREATE INDEX idx_expenses_ts ON expenses(expense_timestamp_ms)');
  }
}
