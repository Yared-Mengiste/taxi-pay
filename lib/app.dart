import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db/app_database.dart';
import 'data/db/payment_repository.dart';
import 'data/sms/sms_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'providers/dashboard_provider.dart';
import 'providers/session_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/background_task_service.dart';
import 'services/csv_export_service.dart';
import 'services/permissions_service.dart';
import 'services/reconciliation_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

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

  /// Explicit user language choice, or null = follow the system locale.
  String? _languageCode;

  /// Saved theme mode; defaults to following the system.
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.settings.languageCode;
    _themeMode = _themeModeFromName(widget.settings.themeModeName);
    WidgetsBinding.instance.addObserver(this);
    // Re-arm the SMS listener on every launch. Cheap and idempotent — and it
    // guarantees the background handler handle is (re)registered with the
    // native side even after the app was killed.
    SmsService.instance.start();
    _backgroundTasks.initialize();
  }

  static ThemeMode _themeModeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

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

  Future<void> _setLanguage(String? code) async {
    await widget.settings.setLanguageCode(code);
    if (!mounted) return;
    setState(() => _languageCode = code);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await widget.settings.setThemeModeName(mode.name);
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => 'Taxi Pay',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Amharic first: an unsupported device locale resolves to am, not en —
      // Amharic is the primary language of this app.
      supportedLocales: const [Locale('am'), Locale('en')],
      locale: _languageCode == null ? null : Locale(_languageCode!),
      home: widget.settings.isOnboarded
          ? MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => SessionProvider(
                    app: widget.app,
                    capturedPayments: SmsService.instance.capturedPayments,
                  )..load(),
                ),
                ChangeNotifierProvider(
                  create: (_) =>
                      DashboardProvider(PaymentRepository(widget.app))..load(),
                ),
              ],
              child: _HomeShell(
                exporter:
                    CsvExportService(PaymentRepository(widget.app)),
                languageCode: _languageCode,
                onLanguageChanged: _setLanguage,
                themeMode: _themeMode,
                onThemeModeChanged: _setThemeMode,
              ),
            )
          : OnboardingScreen(
              settings: widget.settings,
              permissions: PermissionsService(),
            ),
    );
  }
}

/// Two-tab shell: session and dashboard. Both providers sit *above* this
/// widget, so switching tabs never destroys session state, and an
/// [IndexedStack] keeps both trees alive (scroll position, chart state).
class _HomeShell extends StatefulWidget {
  const _HomeShell({
    required this.exporter,
    required this.languageCode,
    required this.onLanguageChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final CsvExportService exporter;
  final String? languageCode;
  final Future<void> Function(String? code) onLanguageChanged;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode mode) onThemeModeChanged;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            languageCode: widget.languageCode,
            onLanguageChanged: widget.onLanguageChanged,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
          DashboardScreen(exporter: widget.exporter),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          // Coming back to the dashboard should reflect payments captured
          // while the user was on the session tab.
          if (index == 1) {
            context.read<DashboardProvider>().reload();
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sensors_rounded),
            selectedIcon: const Icon(Icons.sensors_rounded),
            label: l10n.navSession,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_rounded),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navDashboard,
          ),
        ],
      ),
    );
  }
}
