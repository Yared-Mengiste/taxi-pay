import 'package:flutter/services.dart';

/// Audible + tactile confirmation that a payment was captured.
///
/// The driver's eyes are on the road, not the screen: when a teleBirr SMS
/// lands mid-shift, a short system sound plus a haptic pulse says "it
/// registered" without a glance at the phone. Both effects are injectable
/// callbacks so tests can observe them (and so the platform channels stay
/// wrapped in exactly one small class).
///
/// Chosen over a notifications plugin on purpose: `SystemSound` and
/// `HapticFeedback` need no permission, no dependency and no channel code,
/// and they fire while the app is foregrounded — which is exactly when the
/// driver has the phone in a mount with the screen on.
class PaymentFeedbackService {
  PaymentFeedbackService({
    void Function()? onBeep,
    void Function()? onVibrate,
  })  : _beep = onBeep ?? _systemBeep,
        _vibrate = onVibrate ?? _systemVibrate;

  final void Function() _beep;
  final void Function() _vibrate;

  static void _systemBeep() => SystemSound.play(SystemSoundType.alert);

  static void _systemVibrate() => HapticFeedback.mediumImpact();

  /// Fires both effects. Synchronous and cheap — safe to call straight
  /// from a stream listener with nothing to await.
  void paymentCaptured() {
    _beep();
    _vibrate();
  }
}
