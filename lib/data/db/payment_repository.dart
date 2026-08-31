import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../models/payment.dart';
import 'app_database.dart';

/// One bucket in a revenue aggregate, e.g. day `2026-08-31` -> 4500 cents
/// across 7 payments.
class BucketTotal {
  const BucketTotal(this.bucket, this.totalCents, this.paymentCount);

  /// Bucket key as produced by SQLite, e.g. `2026-08-31` for a daily bucket.
  final String bucket;
  final int totalCents;
  final int paymentCount;
}

class PaymentRepository {
  PaymentRepository(this._app);

  final AppDatabase _app;
  Database get _db => _app.db;

  static final Random _random = Random();

  /// Inserts a parsed teleBirr payment unless its transaction ID already
  /// exists. Returns true when a new row was written.
  ///
  /// `INSERT OR IGNORE` + the `UNIQUE(transaction_id)` constraint is the
  /// dedupe guarantee: the foreground listener, the background SMS isolate
  /// and the reconciliation query can all race to insert the same payment and
  /// exactly one row survives.
  Future<bool> insertTelebirrPaymentIfMissing(Payment payment) async {
    final count = await _db.insert(
      'payments',
      payment.toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return count > 0;
  }

  /// Logs a cash fare. Locally generated transaction id — the timestamp +
  /// randomness is enough to be unique for a single device.
  Future<Payment> addCashPayment({
    required int sessionId,
    required int amountCents,
    int? timestampMs,
  }) async {
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final payment = Payment(
      transactionId:
          'cash:$ts-${_random.nextInt(1 << 32).toRadixString(36)}',
      sessionId: sessionId,
      method: PaymentMethod.cash,
      amountCents: amountCents,
      smsTimestampMs: ts,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.insert('payments', payment.toRow());
    return payment;
  }

  /// Payments of one session, newest first.
  Future<List<Payment>> paymentsForSession(int sessionId) async {
    final rows = await _db.query(
      'payments',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sms_timestamp_ms DESC, id DESC',
    );
    return rows.map(Payment.fromRow).toList();
  }

  /// Sum/count of one session's payments.
  Future<SessionTotals> totalsForSession(int sessionId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total, COUNT(*) AS n '
      'FROM payments WHERE session_id = ?',
      [sessionId],
    );
    final row = rows.first;
    return SessionTotals(
      totalCents: row['total'] as int,
      paymentCount: row['n'] as int,
    );
  }

  /// Payments whose SMS arrived in `[fromMs, toMs)` — used by CSV export.
  Future<List<Payment>> paymentsBetween(int fromMs, int toMs) async {
    final rows = await _db.query(
      'payments',
      where: 'sms_timestamp_ms >= ? AND sms_timestamp_ms < ?',
      whereArgs: [fromMs, toMs],
      orderBy: 'sms_timestamp_ms ASC',
    );
    return rows.map(Payment.fromRow).toList();
  }

  /// Revenue grouped by local calendar day between two Unix-millisecond
  /// timestamps, as `Map<'yyyy-MM-dd', BucketTotal>`.
  ///
  /// The 'localtime' modifier makes SQLite bucket by the device's timezone —
  /// a driver's "day" must match their wall clock, not UTC.
  Future<Map<String, BucketTotal>> dailyTotals(
      int fromMs, int toMs) async {
    final rows = await _db.rawQuery(
      "SELECT strftime('%Y-%m-%d', sms_timestamp_ms / 1000, 'unixepoch', "
      "'localtime') AS bucket, "
      "SUM(amount_cents) AS total, COUNT(*) AS n "
      "FROM payments WHERE sms_timestamp_ms >= ? AND sms_timestamp_ms < ? "
      "GROUP BY bucket",
      [fromMs, toMs],
    );
    return {
      for (final row in rows)
        row['bucket'] as String: BucketTotal(
          row['bucket'] as String,
          row['total'] as int,
          row['n'] as int,
        ),
    };
  }

  /// Grand total between two timestamps (any bucketing is done in Dart).
  Future<int> totalCentsBetween(int fromMs, int toMs) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM payments '
      'WHERE sms_timestamp_ms >= ? AND sms_timestamp_ms < ?',
      [fromMs, toMs],
    );
    return rows.first['total'] as int;
  }
}

class SessionTotals {
  const SessionTotals({required this.totalCents, required this.paymentCount});

  final int totalCents;
  final int paymentCount;
}
