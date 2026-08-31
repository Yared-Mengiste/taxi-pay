import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/db/app_database.dart';
import 'data/sms/sms_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/background_task_service.dart';
import 'services/permissions_service.dart';
import 'services/reconciliation_service.dart';
import 'services/settings_service.dart';

/// Root widget for Taxi Pay.
///
/// Owns the long-lived services (settings, permissions, SMS listener) and
/// decides whether the first run shows the onboarding flow or the home screen.
class TaxiPayApp extends StatefulWidget {
  const TaxiPayApp({super.key});

  @override
  State<TaxiPayApp> createState() => _TaxiPayAppState();
}

class _TaxiPayAppState extends State<TaxiPayApp> with WidgetsBindingObserver {
  late final Future<SettingsService> _settingsFuture;
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
    _settingsFuture =
        SharedPreferences.getInstance().then(SettingsService.new);
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
          await ReconciliationService(await AppDatabase.openDefault())
              .reconcile();
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
      home: FutureBuilder(
        future: _settingsFuture,
        builder: (context, AsyncSnapshot<SettingsService> snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final settings = snapshot.data!;
          if (!settings.isOnboarded) {
            return OnboardingScreen(
              settings: settings,
              permissions: PermissionsService(),
            );
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
