import 'dart:async';
import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../../models/payment.dart';
import 'background_sms_handler.dart';
import 'sms_capture.dart';

/// Foreground half of SMS capture.
///
/// `listenIncomingSms` registers *two* things on the native side:
///  - the foreground callback (fires while the app is visible), and
///  - the background isolate handler (fires no matter what, via the
///    manifest-declared `IncomingSmsReceiver`).
/// Both funnel into [captureSmsMessage]; the UNIQUE(transaction_id)
/// constraint absorbs any double delivery.
///
/// The stream this service exposes is how the UI learns about new payments
/// without polling the database — a Stream, not a callback field, because
/// several widgets may want to react.
class SmsService {
  SmsService._();

  static final SmsService instance = SmsService._();

  final _controller = StreamController<Payment>.broadcast();
  bool _started = false;

  /// Payments captured while the app is in the foreground.
  Stream<Payment> get capturedPayments => _controller.stream;

  /// Re-emits payments inserted by a non-listener path (reconciliation) so
  /// stream subscribers hear about them too.
  void emitCaptured(Payment payment) {
    if (!_controller.isClosed) _controller.add(payment);
  }

  Future<void> start() async {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    Telephony.instance.listenIncomingSms(
      onNewMessage: _onNewMessage,
      onBackgroundMessage: smsBackgroundHandler,
      listenInBackground: true,
    );
  }

  Future<void> _onNewMessage(SmsMessage message) async {
    debugPrint('[taxi-pay/sms] incoming address="${message.address}" '
        'date=${message.date}\n---- body ----\n${message.body}\n-------------');
    final app = await AppDatabase.openDefault();
    final inserted = await captureSmsMessage(
      app,
      address: message.address,
      body: message.body,
      timestampMs: message.date ?? DateTime.now().millisecondsSinceEpoch,
    );
    if (inserted != null) _controller.add(inserted);
  }
}
