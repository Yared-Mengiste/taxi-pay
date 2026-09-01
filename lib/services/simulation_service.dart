import 'dart:math';

import '../data/db/app_database.dart';
import '../data/sms/sms_capture.dart';
import '../data/sms/sms_service.dart';
import '../data/sms/telebirr_parser.dart';
import '../models/payment.dart';

/// Test-payment simulator: builds a realistic teleBirr "payment received"
/// SMS and pushes it through the *real* capture pipeline — sender check,
/// session check, parser, dedupe, insert. No money moves; it exists so a
/// driver (or a demo) can verify capture works without waiting for a
/// passenger to pay.
class SimulationService {
  SimulationService(this._app);

  final AppDatabase _app;

  static final Random _random = Random();

  /// Sends one fake payment. Returns the inserted [Payment], or null when
  /// nothing was captured (no active session). A successful insert is
  /// re-emitted on the capture stream, so the live feed, the beep and the
  /// running total all react exactly as they would to a real SMS.
  Future<Payment?> sendTestPayment({
    required int amountCents,
    String? payerName,
    String? payerPhone,
  }) async {
    final payer = (payerName == null || payerName.trim().isEmpty)
        ? 'Test Payer'
        : payerName.trim();
    final phone = (payerPhone == null || payerPhone.trim().isEmpty)
        ? '09** ***234'
        : payerPhone.trim();
    // A plausible wallet balance after the payment — cosmetic, but it keeps
    // the wallet badge honest-looking in demos.
    final balanceCents = amountCents + 15000 + _random.nextInt(50000);
    final body = 'You have received ETB ${(amountCents / 100).toStringAsFixed(2)} '
        'from $payer ($phone). '
        'Transaction ID: ${_generateTransactionId()}. '
        'Your current balance is ETB ${(balanceCents / 100).toStringAsFixed(2)}.';

    final payment = await captureSmsMessage(
      _app,
      address: telebirrShortCode,
      body: body,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (payment != null) SmsService.instance.emitCaptured(payment);
    return payment;
  }

  /// Random 12-char alphanumeric id in teleBirr's style. Pure alphanumeric
  /// on purpose: the parser's transaction-id group stops at the first
  /// non-alphanumeric character, so dots (as in real `PP260831.1234.AB`
  /// ids) would be truncated — and truncated ids collide.
  String _generateTransactionId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return 'PP${String.fromCharCodes(
      Iterable.generate(10, (_) => chars.codeUnitAt(_random.nextInt(chars.length))),
    )}';
  }
}
