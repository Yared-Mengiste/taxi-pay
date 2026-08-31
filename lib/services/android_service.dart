import 'package:flutter/services.dart';

/// Dart side of the small hand-written `taxi_pay/android` platform channel.
///
/// Kept as a thin, typed wrapper so the rest of the app never touches
/// [MethodChannel] directly.
class AndroidService {
  static const MethodChannel _channel = MethodChannel('taxi_pay/android');

  /// True when both RECEIVE_SMS and READ_SMS are granted.
  ///
  /// This is a *check*, unlike `Telephony.requestSmsPermissions`, which always
  /// fires the system request dialog. The onboarding flow and the settings
  /// screen need to know the state without prompting.
  Future<bool> get isSmsPermissionGranted async =>
      await _channel.invokeMethod<bool>('isSmsPermissionGranted') ?? false;

  Future<bool> get isIgnoringBatteryOptimizations async =>
      await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
      false;

  /// Opens the system dialog asking to exempt the app from Doze.
  ///
  /// Fire-and-forget: check [isIgnoringBatteryOptimizations] when the app
  /// resumes to learn the outcome.
  Future<void> requestIgnoreBatteryOptimizations() =>
      _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');

  /// Opens this app's page in system Settings. This is the destination of the
  /// "Allow restricted settings" flow required for sideloaded APKs on
  /// Android 13+ before runtime permission dialogs can be shown at all.
  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');
}
