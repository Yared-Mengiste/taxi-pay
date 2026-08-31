import 'package:sqflite/sqflite.dart';

import '../../models/expense.dart';
import 'app_database.dart';

/// Storage for session expenses (fuel and other running costs).
///
/// Deliberately a mirror of `PaymentRepository`'s session-scoped reads:
/// the same shapes make the provider wiring and the net-earnings math
/// obvious.
class ExpenseRepository {
  ExpenseRepository(this._app);

  final AppDatabase _app;
  Database get _db => _app.db;

  /// Logs an expense into the running session.
  Future<Expense> addExpense({
    required int sessionId,
    required int amountCents,
    required ExpenseCategory category,
    String? note,
    int? timestampMs,
  }) async {
    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final expense = Expense(
      sessionId: sessionId,
      category: category,
      amountCents: amountCents,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      expenseTimestampMs: ts,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final id = await _db.insert('expenses', expense.toRow());
    return Expense(
      sessionId: expense.sessionId,
      category: expense.category,
      amountCents: expense.amountCents,
      note: expense.note,
      expenseTimestampMs: expense.expenseTimestampMs,
      createdAtMs: expense.createdAtMs,
      id: id,
    );
  }

  /// Expenses of one session, newest first.
  Future<List<Expense>> expensesForSession(int sessionId) async {
    final rows = await _db.query(
      'expenses',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'expense_timestamp_ms DESC, id DESC',
    );
    return rows.map(Expense.fromRow).toList();
  }

  /// Total expenses of one session (0 when none).
  Future<int> totalCentsForSession(int sessionId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses '
      'WHERE session_id = ?',
      [sessionId],
    );
    return rows.first['total'] as int;
  }

  /// Total expenses whose timestamp falls in `[fromMs, toMs)` — the
  /// dashboard's "net for this window" input. Buckets by the same
  /// `expense_timestamp_ms` field the feed sorts on.
  Future<int> totalCentsBetween(int fromMs, int toMs) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses '
      'WHERE expense_timestamp_ms >= ? AND expense_timestamp_ms < ?',
      [fromMs, toMs],
    );
    return rows.first['total'] as int;
  }
}
