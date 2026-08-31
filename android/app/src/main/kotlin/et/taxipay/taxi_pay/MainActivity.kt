package et.taxipay.taxi_pay

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Small hand-written platform channel ("taxi_pay/android") for the Android
 * bits that no Dart plugin covers cleanly:
 *  - checking SMS permission state without triggering a request dialog
 *  - asking the user to exempt the app from battery optimization (Doze)
 *  - jumping to this app's page in system Settings (needed for the
 *    "Allow restricted settings" flow on Android 13+ sideloaded APKs)
 */
class MainActivity : FlutterActivity() {

    private val channelName = "taxi_pay/android"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSmsPermissionGranted" ->
                        result.success(isSmsPermissionGranted())
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" -> {
                        // Fire-and-forget: the system shows a dialog. Dart
                        // re-checks the state when the app resumes.
                        requestIgnoreBatteryOptimizations()
                        result.success(null)
                    }
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isSmsPermissionGranted(): Boolean =
        checkSelfPermission(android.Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED &&
        checkSelfPermission(android.Manifest.permission.READ_SMS) ==
            PackageManager.PERMISSION_GRANTED

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        val intent = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }
}
