import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/sms/sms_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/permissions_service.dart';
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

class _TaxiPayAppState extends State<TaxiPayApp> {
  late final Future<SettingsService> _settingsFuture;

  @override
  void initState() {
    super.initState();
    // Re-arm the SMS listener on every launch. Cheap and idempotent — and it
    // guarantees the background handler handle is (re)registered with the
    // native side even after the app was killed.
    SmsService.instance.start();
    _settingsFuture =
        SharedPreferences.getInstance().then(SettingsService.new);
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
