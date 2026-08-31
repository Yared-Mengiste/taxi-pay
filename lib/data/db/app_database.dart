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
  static const schemaVersion = 1;

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
    );
    return AppDatabase(db);
  }

  static Future<void> configureDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA busy_timeout = 5000');
  }

  static Future<void> createSchema(Database db) async {
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
  }
}
