import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/permissions_service.dart';
import '../../services/settings_service.dart';

/// First-run flow: welcome -> SMS permission -> battery exemption.
///
/// Handles the Android 13+/15 "restricted settings" wall that blocks runtime
/// permission dialogs for sideloaded APKs: when the request comes back
/// denied, we show step-by-step instructions and a button that jumps straight
/// to the app's page in system Settings.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.permissions,
    required this.settings,
    required this.onOnboarded,
  });

  final PermissionsService permissions;
  final SettingsService settings;

  /// Invoked once onboarding is persisted. The app root rebuilds and swaps
  /// this screen for the provider-backed home shell. Navigating to HomeScreen
  /// directly is wrong here: pushed routes are siblings of `MaterialApp.home`,
  /// so they sit *outside* the MultiProvider and blow up on
  /// `Consumer<SessionProvider>`.
  final VoidCallback onOnboarded;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  int _step = 0;

  /// null = not checked yet, false = asked and refused, true = granted.
  bool? _smsGranted;
  bool _smsRequestedAndDenied = false;
  bool? _batteryExempt;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permission states every time the app becomes visible again —
  /// the user may have just granted things in system Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final sms = await widget.permissions.isSmsPermissionGranted;
    final battery = await widget.permissions.isIgnoringBatteryOptimizations;
    if (!mounted) return;
    setState(() {
      _smsGranted = sms;
      if (sms) _smsRequestedAndDenied = false;
      _batteryExempt = battery;
    });
  }

  Future<void> _requestSms() async {
    final granted = await widget.permissions.requestSmsPermissions();
    if (!mounted) return;
    setState(() {
      _smsGranted = granted;
      if (!granted) _smsRequestedAndDenied = true;
    });
    if (granted) _goTo(_step + 1);
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await widget.settings.setOnboarded(true);
    if (!mounted) return;
    widget.onOnboarded();
  }

  void _goTo(int step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildStep(context)),
            _buildDots(),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: switch (_step) {
          0 => _WelcomeStep(onGetStarted: () => _goTo(1)),
          1 => _SmsStep(
              granted: _smsGranted,
              requestedAndDenied: _smsRequestedAndDenied,
              onRequest: _requestSms,
              onOpenSettings: widget.permissions.openAppSettings,
              onRecheck: _refreshStatuses,
              onNext: () => _goTo(2)),
          _ => _BatteryStep(
              exempt: _batteryExempt,
              onRequest: () async {
                await widget.permissions.requestIgnoreBatteryOptimizations();
              },
              onRecheck: _refreshStatuses,
              onDone: _finish),
        },
      ),
    );
  }

  Widget _buildDots() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i == _step;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 28 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFF005CB9), Color(0xFF00A859)],
                    )
                  : null,
              color: active
                  ? null
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final canSkip = _step == 2; // battery step is skippable, SMS is not
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          if (canSkip)
            TextButton(
              onPressed: _finish,
              child: Text(context.l10n.onbSkip),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _step == 2 ? _finish : null,
            child: Text(context.l10n.onbFinish),
          ),
        ],
      ),
    );
  }
}

/// Big icon + title + body copy shared by all steps.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.icon,
    required this.title,
    required this.body,
    this.isSuccess = false,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: isSuccess
                  ? const LinearGradient(
                      colors: [Color(0xFF00A859), Color(0xFF00C853)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF005CB9), Color(0xFF0072CE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isSuccess ? const Color(0xFF00A859) : scheme.primary)
                      .withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        body,
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.local_taxi_rounded,
      title: context.l10n.onbWelcomeTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onbWelcomeBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onGetStarted,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              context.l10n.onbGetStarted,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsStep extends StatelessWidget {
  const _SmsStep({
    required this.granted,
    required this.requestedAndDenied,
    required this.onRequest,
    required this.onOpenSettings,
    required this.onRecheck,
    required this.onNext,
  });

  final bool? granted;
  final bool requestedAndDenied;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final grantedNow = granted == true;
    return _StepScaffold(
      icon: grantedNow ? Icons.check_circle_rounded : Icons.sms_rounded,
      isSuccess: grantedNow,
      title: grantedNow
          ? context.l10n.onbSmsGrantedTitle
          : context.l10n.onbSmsTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onbSmsBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          if (!grantedNow) ...[
            FilledButton.icon(
              onPressed: onRequest,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.key_rounded),
              label: Text(
                context.l10n.onbSmsTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (requestedAndDenied) ...[
              const SizedBox(height: 24),
              _RestrictedSettingsCard(
                onOpenSettings: onOpenSettings,
                onRecheck: onRecheck,
              ),
            ],
          ] else ...[
            FilledButton.icon(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                context.l10n.onbContinue,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when Android refused to even show the permission dialog — this is
/// the "restricted settings" state Android 13+ puts sideloaded APKs in.
class _RestrictedSettingsCard extends StatelessWidget {
  const _RestrictedSettingsCard({
    required this.onOpenSettings,
    required this.onRecheck,
  });

  final VoidCallback onOpenSettings;
  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: scheme.onErrorContainer, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.onbRestrictedTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.onbRestrictedBody,
            style: TextStyle(
              color: scheme.onErrorContainer,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _step(context, '1', context.l10n.onbStep1),
          _step(context, '2', context.l10n.onbStep2),
          _step(context, '3', context.l10n.onbStep3),
          _step(context, '4', context.l10n.onbStep4),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(context.l10n.onbOpenSettings),
              ),
              OutlinedButton(
                onPressed: onRecheck,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                  side: BorderSide(
                    color: scheme.onErrorContainer.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(context.l10n.onbCheckAgain),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, String n, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: scheme.onErrorContainer,
            child: Text(
              n,
              style: TextStyle(
                fontSize: 11,
                color: scheme.errorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatteryStep extends StatelessWidget {
  const _BatteryStep({
    required this.exempt,
    required this.onRequest,
    required this.onRecheck,
    required this.onDone,
  });

  final bool? exempt;
  final VoidCallback onRequest;
  final VoidCallback onRecheck;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final exemptNow = exempt == true;
    return _StepScaffold(
      icon: exemptNow
          ? Icons.battery_charging_full_rounded
          : Icons.battery_saver_rounded,
      isSuccess: exemptNow,
      title: exemptNow
          ? context.l10n.onbBatteryOkTitle
          : context.l10n.onbBatteryTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.onbBatteryBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          if (!exemptNow) ...[
            FilledButton.icon(
              onPressed: onRequest,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.bolt_rounded),
              label: Text(
                context.l10n.onbAllowBackground,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: onRecheck,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(context.l10n.onbCheckAgain),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00A859),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(
                context.l10n.onbAllSet,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
