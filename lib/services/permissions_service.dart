import 'package:another_telephony/telephony.dart';

import 'android_service.dart';

/// One-stop shop for the permissions this app needs.
///
/// - SMS (RECEIVE_SMS + READ_SMS): the core requirement.
/// - Battery-optimization exemption: optional but strongly recommended so the
///   background SMS handler is not deferred by Doze mid-session.
class PermissionsService {
  PermissionsService({AndroidService? android})
      : _android = android ?? AndroidService();

  final AndroidService _android;
  final Telephony _telephony = Telephony.instance;

  Future<bool> get isSmsPermissionGranted => _android.isSmsPermissionGranted;

  Future<bool> get isIgnoringBatteryOptimizations =>
      _android.isIgnoringBatteryOptimizations;

  /// Shows the system SMS permission dialog. Returns true if granted.
  ///
  /// On Android 13+ with sideloaded APKs the dialog is blocked ("restricted
  /// settings") until the user unlocks it from the app's system-settings page;
  /// the onboarding UI handles that case by calling [openAppSettings].
  Future<bool> requestSmsPermissions() async =>
      await _telephony.requestPhoneAndSmsPermissions ?? false;

  Future<void> requestIgnoreBatteryOptimizations() =>
      _android.requestIgnoreBatteryOptimizations();

  Future<void> openAppSettings() => _android.openAppSettings();
}
