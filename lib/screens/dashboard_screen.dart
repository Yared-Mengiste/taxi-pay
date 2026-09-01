import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/db/session_repository.dart';
import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../providers/dashboard_provider.dart';
import '../services/csv_export_service.dart';
import '../util/dates.dart';
import '../util/money.dart';
import '../widgets/export_range_sheet.dart';
import '../widgets/session_details_sheet.dart';

/// Revenue over time: period toggle, summary numbers, one bar per
/// day/week/month. Read-only — everything is aggregated from the DB.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.exporter});

  final CsvExportService exporter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.dashboardTitle),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: context.l10n.exportTooltip,
            onPressed: () => _export(context),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, dashboard, _) {
          if (dashboard.loading && dashboard.buckets.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => dashboard.reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _PeriodSelector(
                  period: dashboard.period,
                  onSelected: dashboard.setPeriod,
                ),
                const SizedBox(height: 16),
                if (!dashboard.hasRevenue)
                  const _EmptyDashboard()
                else ...[
                  _SummaryCard(dashboard: dashboard),
                  const SizedBox(height: 16),
                  _RevenueChartCard(dashboard: dashboard),
                ],
                // Session history answers "what did I make on Tuesday?" —
                // shown even when the chart window has no revenue.
                if (dashboard.sessions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _PastSessionsSection(dashboard: dashboard),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Export flow: pick a window (preset or custom), then share it as CSV.
  /// The picker replaced the old "export whatever is on screen" behavior —
  /// reconciliation against a monthly teleBirr statement needs *that*
  /// month, not whatever the chart happened to show.
  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Strings captured before the await — no context use across the gap.
    final emptyMessage = context.l10n.exportEmpty;
    final doneMessage = context.l10n.exportDone;
    final range = await showExportRangeSheet(context);
    if (range == null || !context.mounted) return;
    final result = await exporter.exportRange(
      from: range.$1,
      to: range.$2,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(result.isEmpty
          ? emptyMessage
          : doneMessage(result.paymentCount!)),
    ));
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onSelected});

  final DashboardPeriod period;
  final ValueChanged<DashboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<DashboardPeriod>(
      segments: [
        ButtonSegment(
          value: DashboardPeriod.day,
          label: Text(l10n.periodDaily),
          icon: const Icon(Icons.today_rounded),
        ),
        ButtonSegment(
          value: DashboardPeriod.week,
          label: Text(l10n.periodWeekly),
          icon: const Icon(Icons.date_range_rounded),
        ),
        ButtonSegment(
          value: DashboardPeriod.month,
          label: Text(l10n.periodMonthly),
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ],
      selected: {period},
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.dashboard});

  final DashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final telebirr = dashboard.byMethod[PaymentMethod.telebirr];
    final cash = dashboard.byMethod[PaymentMethod.cash];
    final periodLabel = switch (dashboard.period) {
      DashboardPeriod.day => l10n.perDay,
      DashboardPeriod.week => l10n.perWeek,
      DashboardPeriod.month => l10n.perMonth,
    };
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  switch (dashboard.period) {
                    DashboardPeriod.day => l10n.window7Days,
                    DashboardPeriod.week => l10n.window8Weeks,
                    DashboardPeriod.month => l10n.window12Months,
                  },
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A859).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics_outlined,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatBirr(dashboard.totalCents),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '${l10n.paymentsCount(dashboard.paymentCount)} · '
            '${l10n.avgPerPeriod(formatBirr(dashboard.averagePerBucketCents), periodLabel)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MethodChip(
                  icon: Icons.phone_iphone_rounded,
                  label: 'teleBirr',
                  amountCents: telebirr?.totalCents ?? 0,
                  count: telebirr?.paymentCount ?? 0,
                  isTelebirr: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodChip(
                  icon: Icons.payments_rounded,
                  label: l10n.actionCash,
                  amountCents: cash?.totalCents ?? 0,
                  count: cash?.paymentCount ?? 0,
                  isTelebirr: false,
                ),
              ),
            ],
          ),
          if (dashboard.expenseTotalCents > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_gas_station_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.expensesLabel(formatBirr(dashboard.expenseTotalCents))} · '
                      '${l10n.netLabel(formatBirr(dashboard.netCents))}',
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.icon,
    required this.label,
    required this.amountCents,
    required this.count,
    required this.isTelebirr,
  });

  final IconData icon;
  final String label;
  final int amountCents;
  final int count;
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
            child: Icon(icon, size: 16, color: Colors.white),
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
                  count == 0 ? '—' : '${formatBirr(amountCents)} ($count)',
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

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.dashboard});

  final DashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxCents = dashboard.buckets.fold<int>(
        0, (max, b) => b.totalCents > max ? b.totalCents : max);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
      child: SizedBox(
        height: 240,
        child: _RevenueBarChart(
          buckets: dashboard.buckets,
          period: dashboard.period,
          maxYBirr: (maxCents / 100) * 1.15, // headroom for tooltip
          barColor: scheme.primary,
        ),
      ),
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({
    required this.buckets,
    required this.period,
    required this.maxYBirr,
    required this.barColor,
  });

  final List<RevenueBucket> buckets;
  final DashboardPeriod period;
  final double maxYBirr;
  final Color barColor;

  String _bottomLabel(DateTime start, String? locale) => switch (period) {
        DashboardPeriod.day => weekdayLabel(start, locale), // ሰኞ / Mon
        DashboardPeriod.week =>
          _mdFormat.format(start), // Monday's date, digits only
        DashboardPeriod.month => monthLabel(start, locale), // ኦገስ / Aug
      };

  static final _mdFormat = DateFormat('M/d');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxYBirr <= 0 ? 1 : maxYBirr,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              formatBirr((rod.toY * 100).round()),
              TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _compactBirr(value),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= buckets.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _bottomLabel(buckets[index].start, locale),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _gridInterval(maxYBirr),
          getDrawingHorizontalLine: (value) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < buckets.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: buckets[i].totalCents / 100,
                  color: buckets[i].isEmpty
                      ? barColor.withValues(alpha: 0.25)
                      : barColor,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// `1500` -> `1.5k`, `250` -> `250` — axis labels stay short.
  String _compactBirr(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  double _gridInterval(double maxY) {
    if (maxY <= 100) return 25;
    if (maxY <= 250) return 50;
    if (maxY <= 1000) return 250;
    if (maxY <= 2500) return 500;
    return (maxY / 5).roundToDouble();
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.dashboardEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.dashboardEmptyBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

/// Every finished shift, newest first, each tappable for the full
/// money-in / money-out timeline of that session.
class _PastSessionsSection extends StatelessWidget {
  const _PastSessionsSection({required this.dashboard});

  final DashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.history_rounded,
                    size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.sessionsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final summary in dashboard.sessions)
          _SessionTile(
            summary: summary,
            onTap: () => showSessionDetailsSheet(
              context,
              dashboard: dashboard,
              summary: summary,
            ),
          ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.summary, required this.onTap});

  final SessionSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final session = summary.session;
    final endedMs = session.endedAtMs ?? session.startedAtMs;
    final subtitle = StringBuffer(
      '${l10n.paymentsCount(summary.paymentCount)} · '
      '${formatDuration(session.startedAtMs, endedMs)}',
    );
    if (summary.expenseTotalCents > 0) {
      subtitle.write(' · ${l10n.netLabel(formatBirr(summary.netCents))}');
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDayTime(session.startedAtMs, locale: locale),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle.toString(),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatBirr(summary.totalCents),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
