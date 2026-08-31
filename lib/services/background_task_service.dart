import 'dart:io' show Platform;

import 'package:workmanager/workmanager.dart';

import '../data/db/app_database.dart';
import 'reconciliation_service.dart';

/// Periodic background reconciliation while a session is active.
///
/// Resume-time reconciliation (in the app lifecycle observer) is the
/// guaranteed path; this WorkManager job is best-effort extra insurance for
/// long shifts where the phone stays in the driver's pocket. WorkManager
/// survives reboots and defers to Doze — with the battery-optimization
/// exemption from onboarding it typically runs at roughly the requested
/// cadence.
class BackgroundTaskService {
  static const String uniqueName = 'taxipay-reconciliation';

  /// Must be called once at app start so the plugin knows which Dart
  /// function to wake for scheduled work.
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(reconciliationCallbackDispatcher);
  }

  /// Idempotent (`keep` policy) — safe to call on every session start.
  Future<void> startPeriodicReconciliation() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      uniqueName,
      'reconciliation',
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> stopPeriodicReconciliation() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(uniqueName);
  }
}

/// WorkManager entry point. Top-level + `@pragma('vm:entry-point')` for the
/// same tree-shaking reasons as the SMS background handler — the native
/// WorkManager reaches this function by raw handle from a separate engine.
@pragma('vm:entry-point')
void reconciliationCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final app = await AppDatabase.openDefault();
    await ReconciliationService(app).reconcile();
    return true;
  });
}
