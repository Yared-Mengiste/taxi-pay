import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/session_provider.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/add_cash_sheet.dart';
import '../widgets/payment_tile.dart';

/// The one screen a driver uses mid-shift: the session control, the live
/// total and the feed of incoming payments. Reachable one tap after launch.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.languageCode,
    this.onLanguageChanged,
    this.themeMode,
    this.onThemeModeChanged,
  });

  final String? languageCode;
  final Future<void> Function(String? code)? onLanguageChanged;
  final ThemeMode? themeMode;
  final Future<void> Function(ThemeMode mode)? onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taxi Pay'),
        centerTitle: false,
        actions: [
          if (onLanguageChanged != null)
            IconButton(
              tooltip: context.l10n.settingsTitle,
              onPressed: () => showSettingsSheet(
                context,
                currentLanguage: languageCode,
                onLanguageSelected: onLanguageChanged!,
                currentTheme: themeMode ?? ThemeMode.system,
                onThemeSelected: onThemeModeChanged!,
              ),
              icon: const Icon(Icons.settings_rounded),
            ),
        ],
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, _) => session.isRunning
            ? _LiveSessionView(session: session)
            : _IdleView(session: session),
      ),
    );
  }
}

/// Settings sheet: language (Amharic primary, English secondary) and
/// theme mode. Small, focused — two choices, no settings screen needed.
Future<void> showSettingsSheet(
  BuildContext context, {
  required String? currentLanguage,
  required Future<void> Function(String? code) onLanguageSelected,
  required ThemeMode currentTheme,
  required Future<void> Function(ThemeMode mode) onThemeSelected,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.settingsTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium),
          ),
          RadioGroup<String?>(
            groupValue: currentLanguage,
            onChanged: (value) {
              Navigator.of(sheetContext).pop();
              onLanguageSelected(value);
            },
            child: Column(
              children: [
                for (final (code, label) in [
                  (null, l10n.languageSystem),
                  ('am', l10n.languageAmharic),
                  ('en', l10n.languageEnglish),
                ])
                  RadioListTile<String?>(
                    value: code,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          const Divider(),
          RadioGroup<ThemeMode>(
            groupValue: currentTheme,
            onChanged: (value) {
              if (value == null) return;
              Navigator.of(sheetContext).pop();
              onThemeSelected(value);
            },
            child: Column(
              children: [
                for (final (mode, label) in [
                  (ThemeMode.system, l10n.themeSystem),
                  (ThemeMode.light, l10n.themeLight),
                  (ThemeMode.dark, l10n.themeDark),
                ])
                  RadioListTile<ThemeMode>(
                    value: mode,
                    title: Text(label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Idle: big Start control (+ summary of the shift that just ended)
// ---------------------------------------------------------------------------

class _IdleView extends StatelessWidget {
  const _IdleView({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final lastEnded = session.lastEndedSession;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (lastEnded != null)
          _ShiftSummaryCard(
            startedAtMs: lastEnded.startedAtMs,
            endedAtMs: lastEnded.endedAtMs ?? lastEnded.startedAtMs,
            totalCents: session.lastEndedTotalCents,
            paymentCount: session.lastEndedPayments.length,
          ),
        const SizedBox(height: 24),
        _StartButton(onPressed: () => context.read<SessionProvider>().start()),
        if (session.walletBalanceCents != null) ...[
          const SizedBox(height: 16),
          _WalletBadge(cents: session.walletBalanceCents!),
        ],
      ],
    );
  }
}

/// "Wallet: 26.68" — the teleBirr balance from the newest captured SMS.
/// Purely informational; it goes stale the moment the driver pays for
/// something outside this app, so it reads as a hint, not ledger truth.
class _WalletBadge extends StatelessWidget {
  const _WalletBadge({required this.cents, this.color});

  final int cents;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.account_balance_wallet_rounded,
            size: 16, color: effectiveColor),
        const SizedBox(width: 6),
        Text(
          context.l10n.walletBalance(formatBirr(cents)),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 56),
                  Text(
                    context.l10n.homeStart,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(letterSpacing: 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.homeIdleHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard({
    required this.startedAtMs,
    required this.endedAtMs,
    required this.totalCents,
    required this.paymentCount,
  });

  final int startedAtMs;
  final int endedAtMs;
  final int totalCents;
  final int paymentCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_circle_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.l10n.shiftFinished,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatBirr(totalCents),
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${l10n.paymentsCount(paymentCount)} · ${formatDuration(startedAtMs, endedAtMs)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live: running total, feed, stop control, cash entry
// ---------------------------------------------------------------------------

class _LiveSessionView extends StatelessWidget {
  const _LiveSessionView({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location_rounded,
                          size: 16, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        l10n.liveSince(formatClock(
                            session.activeSession!.startedAtMs,
                            locale: locale)),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatBirr(session.totalCents),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    l10n.paymentsThisSession(session.paymentCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                  if (session.walletBalanceCents != null) ...[
                    const SizedBox(height: 4),
                    _WalletBadge(
                      cents: session.walletBalanceCents!,
                      color: scheme.onPrimaryContainer,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => promptAndAddCash(context),
                          icon: const Icon(Icons.payments_rounded),
                          label: Text(l10n.actionCash),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.read<SessionProvider>().stop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.errorContainer,
                            foregroundColor: scheme.onErrorContainer,
                          ),
                          icon: const Icon(Icons.stop_circle_rounded),
                          label: Text(l10n.actionStop),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _PaymentFeed(session: session)),
      ],
    );
  }
}

class _PaymentFeed extends StatelessWidget {
  const _PaymentFeed({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final payments = session.payments;
    if (payments.isEmpty) {
      return _EmptyFeed(onAddCash: () => promptAndAddCash(context));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: payments.length,
      itemBuilder: (context, index) =>
          PaymentTile(payment: payments[index]),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onAddCash});

  final VoidCallback onAddCash;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              l10n.feedWaitingTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.feedWaitingBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAddCash,
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n.feedAddCash),
            ),
          ],
        ),
      ),
    );
  }
}
