import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/db/app_database.dart';
import 'data/db/expense_repository.dart';
import 'data/db/payment_repository.dart';
import 'data/db/session_repository.dart';
import 'data/sms/sms_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'models/payment.dart';
import 'providers/dashboard_provider.dart';
import 'providers/session_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'services/background_task_service.dart';
import 'services/backup_service.dart';
import 'services/csv_export_service.dart';
import 'services/payment_feedback_service.dart';
import 'services/permissions_service.dart';
import 'services/simulation_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

/// Root widget for Taxi Pay. Settings and the database are injected (created
/// once in `main`), so the whole widget tree below is synchronous.
class TaxiPayApp extends StatefulWidget {
  const TaxiPayApp({
    super.key,
    required this.settings,
    required this.app,
    this.feedback,
  });

  final SettingsService settings;
  final AppDatabase app;

  /// Beep/vibrate on captured payments; injectable for tests.
  final PaymentFeedbackService? feedback;

  @override
  State<TaxiPayApp> createState() => _TaxiPayAppState();
}

class _TaxiPayAppState extends State<TaxiPayApp> {
  final BackgroundTaskService _backgroundTasks = BackgroundTaskService();
  late final PaymentFeedbackService _feedback =
      widget.feedback ?? PaymentFeedbackService();
  StreamSubscription<Payment>? _feedbackSubscription;

  /// Explicit user language choice, or null = follow the system locale.
  String? _languageCode;

  /// Saved theme mode; defaults to Light Mode on first open.
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _languageCode = widget.settings.languageCode;
    _themeMode = _themeModeFromName(widget.settings.themeModeName);
    // Re-arm the SMS listener on every launch. Cheap and idempotent — and it
    // guarantees the background handler handle is (re)registered with the
    // native side even after the app was killed.
    SmsService.instance.start();
    _backgroundTasks.initialize();
    // "It registered" without looking at the screen: every payment that
    // lands while we're in the foreground (live listener, simulator or
    // reconciliation) gets a beep + haptic. Background-isolate captures
    // can't beep — that would need a real notification; the resume-time
    // reconciliation still makes them visible.
    _feedbackSubscription =
        SmsService.instance.capturedPayments.listen((_) {
      _feedback.paymentCaptured();
    });
  }

  static ThemeMode _themeModeFromName(String? name) => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light, // Default to light mode on first open
      };

  @override
  void dispose() {
    _feedbackSubscription?.cancel();
    super.dispose();
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
                    onReconciledPayment:
                        SmsService.instance.emitCaptured,
                  )..load(),
                ),
                ChangeNotifierProvider(
                  create: (_) => DashboardProvider(
                    payments: PaymentRepository(widget.app),
                    expenses: ExpenseRepository(widget.app),
                    sessions: SessionRepository(widget.app),
                  )..load(),
                ),
              ],
              child: _HomeShell(
                exporter:
                    CsvExportService(PaymentRepository(widget.app)),
                backup: BackupService(widget.app),
                simulation: SimulationService(widget.app),
                languageCode: _languageCode,
                onLanguageChanged: _setLanguage,
                themeMode: _themeMode,
                onThemeModeChanged: _setThemeMode,
              ),
            )
          : OnboardingScreen(
              settings: widget.settings,
              permissions: PermissionsService(),
              // Swaps the home route for the provider-backed shell. Routes
              // pushed from onboarding would not see the MultiProvider.
              onOnboarded: () => setState(() {}),
            ),
    );
  }
}

/// Three-tab shell: session, dashboard and settings. Both feature providers
/// sit *above* this widget, so switching tabs never destroys session state,
/// and an [IndexedStack] keeps all trees alive (scroll position, chart
/// state, permission statuses).
class _HomeShell extends StatefulWidget {
  const _HomeShell({
    required this.exporter,
    required this.backup,
    required this.simulation,
    required this.languageCode,
    required this.onLanguageChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final CsvExportService exporter;
  final BackupService backup;
  final SimulationService simulation;
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
          HomeScreen(simulation: widget.simulation),
          DashboardScreen(exporter: widget.exporter),
          SettingsScreen(
            backup: widget.backup,
            languageCode: widget.languageCode,
            onLanguageChanged: widget.onLanguageChanged,
            themeMode: widget.themeMode,
            onThemeModeChanged: widget.onThemeModeChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() => _index = index);
          // Coming back to the dashboard should reflect payments captured
          // while the user was on another tab.
          if (index == 1) {
            context.read<DashboardProvider>().reload();
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sensors_outlined),
            selectedIcon: const Icon(Icons.sensors_rounded),
            label: l10n.navSession,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: l10n.navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}
