import '../models/payment.dart';
import 'dates.dart';

/// Minimal RFC 4180 field escaping: wrap in quotes when the field contains
/// a comma, quote, newline or CR; double embedded quotes.
String csvField(Object? value) {
  final s = value?.toString() ?? '';
  final needsQuoting =
      s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
  if (!needsQuoting) return s;
  return '"${s.replaceAll('"', '""')}"';
}

String _birr(int cents) => (cents / 100).toStringAsFixed(2);

/// Builds the export CSV for a list of payments (already date-filtered).
///
/// The UTF-8 BOM is prepended by the caller when writing the file — it makes
/// Excel open Amharic payer names correctly instead of mojibake.
String buildPaymentsCsv(List<Payment> payments) {
  final buffer = StringBuffer();
  buffer.writeln([
    'Date',
    'Time',
    'Method',
    'Amount (ETB)',
    'Transaction ID',
    'Payer name',
    'Payer phone',
    'Balance after (ETB)',
  ].map(csvField).join(','));
  for (final p in payments) {
    buffer.writeln([
      _ymd(p.smsTimestampMs),
      formatClock(p.smsTimestampMs),
      p.method == PaymentMethod.cash ? 'Cash' : 'teleBirr',
      _birr(p.amountCents),
      p.transactionId,
      p.payerName,
      p.payerPhone,
      p.balanceAfterCents == null ? '' : _birr(p.balanceAfterCents!),
    ].map(csvField).join(','));
  }
  return buffer.toString();
}

String _ymd(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
