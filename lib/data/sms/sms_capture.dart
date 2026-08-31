import 'package:flutter/foundation.dart';

import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/data/db/payment_repository.dart';
import 'package:taxi_pay/data/db/session_repository.dart';
import 'package:taxi_pay/data/sms/telebirr_parser.dart';
import 'package:taxi_pay/models/payment.dart';

/// The one capture pipeline shared by every entry point: the foreground
/// listener, the background SMS isolate, and (later) reconciliation.
///
/// Rules, in order:
/// 1. sender address must be exactly teleBirr's short code 127;
/// 2. a session must be active (v1 tracks payments during shifts only);
/// 3. the body must parse as a received-payment confirmation;
/// 4. the transaction id must be new (UNIQUE + INSERT OR IGNORE).
///
/// Returns the inserted [Payment], or null when nothing was written (foreign
/// sender / no session / unparseable / duplicate). Being a plain function
/// over an [AppDatabase], it runs identically on any isolate and is unit
/// testable with an in-memory database.
///
/// Every drop is logged: capture failures are invisible otherwise (no
/// exception, no UI feedback), and "why didn't my payment show up" is the
/// first thing anyone debugging this app needs to know.
Future<Payment?> captureSmsMessage(
  AppDatabase app, {
  required String? address,
  required String? body,
  required int timestampMs,
}) async {
  if (!isFromTelebirr(address)) {
    _log('dropped: sender "$address" is not teleBirr 127');
    return null;
  }

  final sessions = SessionRepository(app);
  final session = await sessions.activeSession();
  if (session == null) {
    _log('dropped: no active session (tap Start on the home screen)');
    return null;
  }

  final parsed = parseTelebirrSms(body);
  if (parsed == null) {
    _log('dropped: body did not parse as a received-payment confirmation.\n'
        '---- body from 127 ----\n$body\n------------------------');
    return null;
  }

  final payment = Payment(
    transactionId: parsed.transactionId,
    sessionId: session.id,
    method: PaymentMethod.telebirr,
    amountCents: parsed.amountCents,
    payerName: parsed.payerName,
    payerPhone: parsed.payerPhoneMasked,
    balanceAfterCents: parsed.balanceAfterCents,
    smsTimestampMs: timestampMs,
    createdAtMs: DateTime.now().millisecondsSinceEpoch,
  );

  final inserted =
      await PaymentRepository(app).insertTelebirrPaymentIfMissing(payment);
  if (!inserted) {
    _log('dropped: duplicate transaction id ${parsed.transactionId}');
    return null;
  }
  _log('captured ${parsed.amountCents / 100} Birr, '
      'tx ${parsed.transactionId}, session ${session.id}');
  return payment;
}

void _log(String message) => debugPrint('[taxi-pay/sms] $message');
