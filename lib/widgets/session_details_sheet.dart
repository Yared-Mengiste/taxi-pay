import 'package:flutter/material.dart';

import '../data/db/session_repository.dart';
import '../l10n/l10n.dart';
import '../models/expense.dart';
import '../models/feed_item.dart';
import '../models/payment.dart';
import '../providers/dashboard_provider.dart';
import '../util/dates.dart';
import '../util/money.dart';
import 'expense_tile.dart';
import 'payment_tile.dart';

/// Drill-down for one past session: header with the shift's numbers, then
/// the full money-in / money-out timeline (same merged feed as the live
/// screen, but read-only — history is not editable).
Future<void> showSessionDetailsSheet(
  BuildContext context, {
  required DashboardProvider dashboard,
  required SessionSummary summary,
}) {
  // The future is created once, outside the builder — FutureBuilder must
  // not re-query on every rebuild.
  final detail = dashboard.loadSessionDetail(summary.session.id);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.of(sheetContext).size.height * 0.75,
      child: FutureBuilder<SessionDetail>(
        future: detail,
        builder: (sheetContext, snapshot) {
          final l10n = sheetContext.l10n;
          final scheme = Theme.of(sheetContext).colorScheme;
          final session = summary.session;
          final endedMs =
              session.endedAtMs ?? session.startedAtMs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag_circle_rounded,
                            color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            formatDayTime(session.startedAtMs,
                                locale: Localizations.maybeLocaleOf(
                                    sheetContext)
                                    ?.toString()),
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                        Text(
                          formatDuration(session.startedAtMs, endedMs),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatBirr(summary.totalCents),
                      style: Theme.of(sheetContext)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (summary.expenseTotalCents > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.expensesLabel(formatBirr(summary.expenseTotalCents))} · '
                        '${l10n.netLabel(formatBirr(summary.netCents))}',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    Text(
                      l10n.paymentsCount(summary.paymentCount),
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: snapshot.connectionState != ConnectionState.done
                    ? const Center(child: CircularProgressIndicator())
                    : _DetailFeed(
                        payments: snapshot.data?.payments ?? const [],
                        expenses: snapshot.data?.expenses ?? const [],
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DetailFeed extends StatelessWidget {
  const _DetailFeed({required this.payments, required this.expenses});

  final List<Payment> payments;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty && expenses.isEmpty) {
      return Center(
        child: Text(
          context.l10n.sessionNoPayments,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }
    // Same interleaved timeline as the live feed: money in and money out,
    // newest first — the shift's actual story, told after the fact.
    final items = <FeedItem>[
      ...payments.map(FeedItem.payment),
      ...expenses.map(FeedItem.expense),
    ]..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      itemCount: items.length,
      itemBuilder: (context, index) => switch (items[index]) {
        FeedPayment(:final payment) =>
          PaymentTile(payment: payment), // history is read-only
        FeedExpense(:final expense) => ExpenseTile(expense: expense),
      },
    );
  }
}
