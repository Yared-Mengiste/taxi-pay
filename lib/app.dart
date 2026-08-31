import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db/app_database.dart';
import 'data/sms/sms_service.dart';
import 'providers/session_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/background_task_service.dart';
import 'services/permissions_service.dart';
import 'services/reconciliation_service.dart';
import 'services/settings_service.dart';

/// Root widget for Taxi Pay. Settings and the database are injected (created
/// once in `main`), so the whole widget tree below is synchronous.
class TaxiPayApp extends StatefulWidget {
  const TaxiPayApp({
    super.key,
    required this.settings,
    required this.app,
  });

  final SettingsService settings;
  final AppDatabase app;

  @override
  State<TaxiPayApp> createState() => _TaxiPayAppState();
}

class _TaxiPayAppState extends State<TaxiPayApp> with WidgetsBindingObserver {
  final BackgroundTaskService _backgroundTasks = BackgroundTaskService();
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Re-arm the SMS listener on every launch. Cheap and idempotent — and it
    // guarantees the background handler handle is (re)registered with the
    // native side even after the app was killed.
    SmsService.instance.start();
    _backgroundTasks.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The reconciliation guarantee: every time the app comes back to the
  /// foreground, diff the device's teleBirr inbox against local storage for
  /// the running session and insert anything the live path missed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed || _reconciling) return;
    _reconciling = true;
    try {
      final inserted =
          await ReconciliationService(widget.app).reconcile();
      for (final payment in inserted) {
        SmsService.instance.emitCaptured(payment);
      }
    } catch (_) {
      // Inbox queries throw without READ_SMS (e.g. permission revoked).
      // The settings screen surfaces that; never crash the resume path.
    } finally {
      _reconciling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxi Pay',
      theme: ThemeData(useMaterial3: true),
      home: widget.settings.isOnboarded
          ? ChangeNotifierProvider(
              create: (_) => SessionProvider(
                app: widget.app,
                capturedPayments: SmsService.instance.capturedPayments,
              )..load(),
              child: const HomeScreen(),
            )
          : OnboardingScreen(
              settings: widget.settings,
              permissions: PermissionsService(),
            ),
    );
  }
}
