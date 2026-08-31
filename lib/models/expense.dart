/// What the money went to. Fuel dominates a taxi's running costs, so it
/// gets its own category (and its own button); everything else — oil,
/// parking, a spare part — is `other` with an optional note.
enum ExpenseCategory {
  fuel,
  other;

  String get storedName => name;

  static ExpenseCategory fromStoredName(String name) =>
      values.firstWhere((c) => c.name == name);
}

/// One running cost logged during a session — the other half of the
/// earnings picture. Gross tells you the day was busy; gross minus this
/// tells you it was worth it.
///
/// Mirrors [Payment]: integer cents, session-scoped, immutable once
/// written (v1 scope — corrections can be added the same way cash edits
/// were).
class Expense {
  const Expense({
    required this.sessionId,
    required this.category,
    required this.amountCents,
    required this.expenseTimestampMs,
    required this.createdAtMs,
    this.id,
    this.note,
  });

  final int? id;
  final int sessionId;
  final ExpenseCategory category;
  final int amountCents;

  /// Free text ("full tank", "engine oil") — optional.
  final String? note;

  final int expenseTimestampMs;
  final int createdAtMs;

  double get amountBirr => amountCents / 100.0;

  Map<String, Object?> toRow() => {
        'session_id': sessionId,
        'category': category.storedName,
        'amount_cents': amountCents,
        'note': note,
        'expense_timestamp_ms': expenseTimestampMs,
        'created_at_ms': createdAtMs,
      };

  static Expense fromRow(Map<String, Object?> row) => Expense(
        id: row['id'] as int?,
        sessionId: row['session_id'] as int,
        category: ExpenseCategory.fromStoredName(row['category'] as String),
        amountCents: row['amount_cents'] as int,
        note: row['note'] as String?,
        expenseTimestampMs: row['expense_timestamp_ms'] as int,
        createdAtMs: row['created_at_ms'] as int,
      );
}
