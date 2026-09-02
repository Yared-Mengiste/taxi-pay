import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../data/db/session_repository.dart';
import '../models/feed_item.dart';
import '../models/payment.dart';
import '../providers/session_provider.dart';
import '../services/simulation_service.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/add_cash_sheet.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/edit_cash_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/payment_tile.dart';
import '../widgets/simulate_payment_sheet.dart';

/// The one screen a driver uses mid-shift: the session control, the live
/// total and the feed of incoming payments. Reachable one tap after launch.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.simulation});

  final SimulationService simulation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF005CB9), Color(0xFF00A859)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.local_taxi_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Taxi Pay'),
          ],
        ),
        centerTitle: false,
        actions: [
          // Test-payment trigger: enabled only while a session runs,
          // because capture drops everything outside a session.
          Consumer<SessionProvider>(
            builder: (context, session, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                tooltip: context.l10n.simulateTooltip,
                onPressed: session.isRunning
                    ? () => showSimulatePaymentSheet(
                          context,
                          simulation: simulation,
                        )
                    : null,
                icon: const Icon(Icons.science_outlined, size: 20),
              ),
            ),
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

// ---------------------------------------------------------------------------
// Idle: big Start control + the last few finished shifts
// ---------------------------------------------------------------------------

class _IdleView extends StatelessWidget {
  const _IdleView({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final recent = session.recentSessions;
    final older = recent.skip(1).toList();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (recent.isNotEmpty) ...[
          _ShiftSummaryCard(summary: recent.first),
          if (older.isNotEmpty) ...[
            const SizedBox(height: 20),
            _RecentRoutesSection(routes: older),
          ],
          const SizedBox(height: 32),
        ] else ...[
          const SizedBox(height: 48),
        ],
        _StartButton(onPressed: () => context.read<SessionProvider>().start()),
        if (session.walletBalanceCents != null) ...[
          const SizedBox(height: 24),
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
    final effectiveColor = color ?? scheme.primary;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                size: 16, color: effectiveColor),
            const SizedBox(width: 8),
            Text(
              context.l10n.walletBalance(formatBirr(cents)),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: effectiveColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      ),
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
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF005CB9), Color(0xFF003E80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 68,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.l10n.homeIdleHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final startedAtMs = summary.session.startedAtMs;
    final endedAtMs = summary.session.endedAtMs ?? startedAtMs;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.flag_circle_rounded,
                  color: scheme.onTertiaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.shiftFinished,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  formatDuration(startedAtMs, endedAtMs),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatBirr(summary.totalCents),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 6),
          if (summary.expenseTotalCents > 0) ...[
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.expensesLabel(formatBirr(summary.expenseTotalCents)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.netLabel(formatBirr(summary.netCents)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l10n.paymentsCount(summary.paymentCount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// "Recent routes" — the shifts before the newest one, at a glance: when it
/// ran, how long, how many payments, how much it grossed.
class _RecentRoutesSection extends StatelessWidget {
  const _RecentRoutesSection({required this.routes});

  final List<SessionSummary> routes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l10n.recentRoutes,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        for (final route in routes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentRouteTile(summary: route),
          ),
      ],
    );
  }
}

class _RecentRouteTile extends StatelessWidget {
  const _RecentRouteTile({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final scheme = Theme.of(context).colorScheme;
    final startedAtMs = summary.session.startedAtMs;
    final endedAtMs = summary.session.endedAtMs ?? startedAtMs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.route_rounded,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDayTime(startedAtMs, locale: locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(startedAtMs, endedAtMs)}'
                  ' · ${l10n.paymentsCount(summary.paymentCount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatBirr(summary.totalCents),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF005CB9), Color(0xFF003E80)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF005CB9).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Pulsing green live indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF00E676),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.liveSince(formatClock(
                              session.activeSession!.startedAtMs,
                              locale: locale)),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      // Elapsed clock
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _ElapsedTicker(
                            startedAtMs: session.activeSession!.startedAtMs),
                      ),
                      const SizedBox(width: 8),
                      _SyncButton(session: session),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    formatBirr(session.totalCents),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.paymentsThisSession(session.paymentCount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LiveMethodStat(
                          icon: Icons.phone_iphone_rounded,
                          label: 'teleBirr',
                          amountCents: session.telebirrTotalCents,
                          isTelebirr: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LiveMethodStat(
                          icon: Icons.payments_rounded,
                          label: l10n.actionCash,
                          amountCents: session.cashTotalCents,
                          isTelebirr: false,
                        ),
                      ),
                    ],
                  ),
                  if (session.expenseTotalCents > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${l10n.expensesLabel(formatBirr(session.expenseTotalCents))} · '
                        '${l10n.netLabel(formatBirr(session.netCents))}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                      ),
                    ),
                  ],
                  if (session.walletBalanceCents != null) ...[
                    const SizedBox(height: 8),
                    _WalletBadge(
                      cents: session.walletBalanceCents!,
                      color: Colors.white,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => promptAndAddExpense(context),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.local_gas_station_rounded,
                              size: 18),
                          label: Text(l10n.actionFuel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => promptAndAddCash(context),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon: const Icon(Icons.payments_rounded, size: 18),
                          label: Text(l10n.actionCash),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _confirmAndStop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          icon:
                              const Icon(Icons.stop_circle_rounded, size: 18),
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

  /// Stop is destructive (ends the shift and freezes the feed), so it goes
  /// through a confirm dialog — the same pattern as cash-entry deletion.
  /// The provider is captured before the await (async-gap rule).
  Future<void> _confirmAndStop(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.stopConfirmTitle),
        content: Text(l10n.stopConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.stopConfirmCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  Theme.of(dialogContext).colorScheme.error,
              foregroundColor:
                  Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.stopConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await session.stop();
  }
}

/// The session clock: `2h 14m`, ticking once a second. Scoped to this
/// tiny widget so the rest of the live view doesn't rebuild every tick.
class _ElapsedTicker extends StatefulWidget {
  const _ElapsedTicker({required this.startedAtMs});

  final int startedAtMs;

  @override
  State<_ElapsedTicker> createState() => _ElapsedTickerState();
}

class _ElapsedTickerState extends State<_ElapsedTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatDuration(
          widget.startedAtMs, DateTime.now().millisecondsSinceEpoch),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}

/// Manual "sync now": runs one inbox reconciliation pass and reports the
/// outcome. The icon morphs into a spinner while it runs.
class _SyncButton extends StatelessWidget {
  const _SyncButton({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: session.isReconciling
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : IconButton(
              tooltip: l10n.syncTooltip,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.white,
              onPressed: () => _syncNow(context),
              icon: const Icon(Icons.sync_rounded, size: 18),
            ),
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    // Strings captured before the await — reconcile hits the inbox.
    final recovered = l10n.syncRecovered;
    final upToDate = l10n.syncUpToDate;
    final failed = l10n.syncFailed;
    try {
      final inserted = await session.reconcile();
      messenger.showSnackBar(SnackBar(
        content: Text(
            inserted > 0 ? recovered(inserted) : upToDate),
      ));
    } catch (_) {
      // Inbox reads throw without READ_SMS — the one error worth naming,
      // because "silently nothing" looks like "no missed payments".
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }
}

/// teleBirr vs cash split on the live card — frosted glass look on gradient background
class _LiveMethodStat extends StatelessWidget {
  const _LiveMethodStat({
    required this.icon,
    required this.label,
    required this.amountCents,
    required this.isTelebirr,
  });

  final IconData icon;
  final String label;
  final int amountCents;
  final bool isTelebirr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isTelebirr
                  ? const Color(0xFF00A859).withValues(alpha: 0.3)
                  : const Color(0xFFFFA000).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  amountCents == 0 ? '—' : formatBirr(amountCents),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFeed extends StatelessWidget {
  const _PaymentFeed({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    if (session.payments.isEmpty && session.expenses.isEmpty) {
      return _EmptyFeed(onAddCash: () => promptAndAddCash(context));
    }
    // One timeline: money in and money out interleaved, newest first —
    // the shift's actual story.
    final items = <FeedItem>[
      ...session.payments.map(FeedItem.payment),
      ...session.expenses.map(FeedItem.expense),
    ]..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      itemBuilder: (context, index) => switch (items[index]) {
        FeedPayment(:final payment) => PaymentTile(
            payment: payment,
            // Cash is the driver's own entry — fixable. SMS rows stay
            // immutable (they're the receipts).
            onEdit: payment.method == PaymentMethod.cash
                ? () => promptAndEditCash(context, payment: payment)
                : null,
          ),
        FeedExpense(:final expense) => ExpenseTile(expense: expense),
      },
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.sensors_rounded,
                        size: 32,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.feedWaitingTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.feedWaitingBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: onAddCash,
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text(l10n.feedAddCash),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
