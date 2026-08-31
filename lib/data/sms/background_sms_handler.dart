import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'sms_capture.dart';

/// Background SMS entry point — called by another_telephony on a **background
/// isolate** whenever an SMS arrives, even when the app is killed.
///
/// The `@pragma('vm:entry-point')` is not decoration: the function is only
/// ever reached through its callback *handle* (a raw integer the native side
/// stores), so the Dart tree-shaker sees no reference to it and would strip
/// it from the release APK without this annotation.
@pragma('vm:entry-point')
Future<void> smsBackgroundHandler(SmsMessage message) async {
  debugPrint('[taxi-pay/sms] background incoming address="${message.address}" '
      'date=${message.date}\n---- body ----\n${message.body}\n-------------');
  await captureSmsMessage(
    await AppDatabase.openDefault(),
    address: message.address,
    body: message.body,
    timestampMs:
        message.date ?? DateTime.now().millisecondsSinceEpoch,
  );
}
