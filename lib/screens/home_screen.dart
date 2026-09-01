import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
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
        title: const Text('Taxi Pay'),
        centerTitle: false,
        actions: [
          // Test-payment trigger: enabled only while a session runs,
          // because capture drops everything outside a session.
          Consumer<SessionProvider>(
            builder: (context, session, _) => IconButton(
              tooltip: context.l10n.simulateTooltip,
              onPressed: session.isRunning
                  ? () => showSimulatePaymentSheet(
                        context,
                        simulation: simulation,
                      )
                  : null,
              icon: const Icon(Icons.science_outlined),
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
            expenseTotalCents: session.lastEndedExpenseTotalCents,
            netCents: session.lastEndedNetCents,
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
    required this.expenseTotalCents,
    required this.netCents,
    required this.paymentCount,
  });

  final int startedAtMs;
  final int endedAtMs;
  final int totalCents;
  final int expenseTotalCents;
  final int netCents;
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
            if (expenseTotalCents > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.expensesLabel(formatBirr(expenseTotalCents))} · '
                '${l10n.netLabel(formatBirr(netCents))}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
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
                      Expanded(
                        child: Text(
                          l10n.liveSince(formatClock(
                              session.activeSession!.startedAtMs,
                              locale: locale)),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      // Elapsed clock + manual inbox diff — the two things
                      // a driver glances at mid-shift.
                      _ElapsedTicker(
                          startedAtMs: session.activeSession!.startedAtMs),
                      const SizedBox(width: 8),
                      _SyncButton(session: session),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _LiveMethodStat(
                          icon: Icons.phone_iphone_rounded,
                          label: 'teleBirr',
                          amountCents: session.telebirrTotalCents,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LiveMethodStat(
                          icon: Icons.payments_rounded,
                          label: l10n.actionCash,
                          amountCents: session.cashTotalCents,
                        ),
                      ),
                    ],
                  ),
                  if (session.expenseTotalCents > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.expensesLabel(formatBirr(session.expenseTotalCents))} · '
                      '${l10n.netLabel(formatBirr(session.netCents))}',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
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
                          onPressed: () => promptAndAddExpense(context),
                          icon: const Icon(Icons.local_gas_station_rounded),
                          label: Text(l10n.actionFuel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => promptAndAddCash(context),
                          icon: const Icon(Icons.payments_rounded),
                          label: Text(l10n.actionCash),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _confirmAndStop(context),
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
                  Theme.of(dialogContext).colorScheme.errorContainer,
              foregroundColor:
                  Theme.of(dialogContext).colorScheme.onErrorContainer,
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
    final scheme = Theme.of(context).colorScheme;
    return Text(
      formatDuration(
          widget.startedAtMs, DateTime.now().millisecondsSinceEpoch),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
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
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 32,
      height: 32,
      child: session.isReconciling
          ? Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            )
          : IconButton(
              tooltip: l10n.syncTooltip,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: scheme.onPrimaryContainer,
              onPressed: () => _syncNow(context),
              icon: const Icon(Icons.sync_rounded, size: 20),
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

/// teleBirr vs cash split on the live card — same shape as the dashboard's
/// method chips, on container colors.
class _LiveMethodStat extends StatelessWidget {
  const _LiveMethodStat({
    required this.icon,
    required this.label,
    required this.amountCents,
  });

  final IconData icon;
  final String label;
  final int amountCents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: scheme.onPrimaryContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                amountCents == 0 ? '—' : formatBirr(amountCents),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
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
    // Centered when there's room, scrollable when the live card (taller
    // since the method split landed) leaves little — never overflows.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
          ),
        ),
      ),
    );
  }
}
