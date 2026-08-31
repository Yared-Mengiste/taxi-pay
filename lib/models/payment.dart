/// How a payment was received.
enum PaymentMethod {
  telebirr,
  cash;

  String get storedName => name;

  static PaymentMethod fromStoredName(String name) =>
      values.firstWhere((m) => m.name == name);
}

/// One incoming payment, either a parsed teleBirr SMS or a manually logged
/// cash fare.
///
/// Amounts are stored as integer **cents** (1 birr = 100 cents). Never store
/// money as `double`: binary floats cannot represent values like `0.10`
/// exactly and sums drift (`0.1 + 0.2 != 0.3`) — unacceptable for a revenue
/// tracker.
class Payment {
  const Payment({
    required this.transactionId,
    required this.sessionId,
    required this.method,
    required this.amountCents,
    required this.smsTimestampMs,
    required this.createdAtMs,
    this.id,
    this.payerName,
    this.payerPhone,
    this.balanceAfterCents,
  });

  final int? id;

  /// teleBirr transaction ID — the natural dedupe key, since teleBirr issues
  /// exactly one per payment. For cash entries a locally generated id is used.
  final String transactionId;

  final int sessionId;
  final PaymentMethod method;
  final int amountCents;
  final String? payerName;

  /// Masked payer phone exactly as teleBirr prints it, e.g. `09** ***234`.
  final String? payerPhone;

  final int? balanceAfterCents;

  /// When the SMS arrived on the device (or a cash fare was logged).
  final int smsTimestampMs;

  /// When this row was written — useful to distinguish "captured live" from
  /// "picked up by reconciliation" while debugging.
  final int createdAtMs;

  double get amountBirr => amountCents / 100.0;

  Map<String, Object?> toRow() => {
        'transaction_id': transactionId,
        'session_id': sessionId,
        'method': method.storedName,
        'amount_cents': amountCents,
        'payer_name': payerName,
        'payer_phone': payerPhone,
        'balance_after_cents': balanceAfterCents,
        'sms_timestamp_ms': smsTimestampMs,
        'created_at_ms': createdAtMs,
      };

  static Payment fromRow(Map<String, Object?> row) => Payment(
        id: row['id'] as int?,
        transactionId: row['transaction_id'] as String,
        sessionId: row['session_id'] as int,
        method: PaymentMethod.fromStoredName(row['method'] as String),
        amountCents: row['amount_cents'] as int,
        payerName: row['payer_name'] as String?,
        payerPhone: row['payer_phone'] as String?,
        balanceAfterCents: row['balance_after_cents'] as int?,
        smsTimestampMs: row['sms_timestamp_ms'] as int,
        createdAtMs: row['created_at_ms'] as int,
      );
}
