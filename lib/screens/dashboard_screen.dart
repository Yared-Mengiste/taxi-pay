import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/payment.dart';
import '../providers/dashboard_provider.dart';
import '../util/money.dart';

/// Revenue over time: period toggle, summary numbers, one bar per
/// day/week/month. Read-only — everything is aggregated from the DB.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: false,
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onSelected});

  final DashboardPeriod period;
  final ValueChanged<DashboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DashboardPeriod>(
      segments: const [
        ButtonSegment(
          value: DashboardPeriod.day,
          label: Text('Daily'),
          icon: Icon(Icons.today_rounded),
        ),
        ButtonSegment(
          value: DashboardPeriod.week,
          label: Text('Weekly'),
          icon: Icon(Icons.date_range_rounded),
        ),
        ButtonSegment(
          value: DashboardPeriod.month,
          label: Text('Monthly'),
          icon: Icon(Icons.calendar_month_rounded),
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
    final scheme = Theme.of(context).colorScheme;
    final telebirr = dashboard.byMethod[PaymentMethod.telebirr];
    final cash = dashboard.byMethod[PaymentMethod.cash];
    final periodLabel = switch (dashboard.period) {
      DashboardPeriod.day => 'day',
      DashboardPeriod.week => 'week',
      DashboardPeriod.month => 'month',
    };
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              switch (dashboard.period) {
                DashboardPeriod.day => 'Last 7 days',
                DashboardPeriod.week => 'Last 8 weeks',
                DashboardPeriod.month => 'Last 12 months',
              },
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              formatBirr(dashboard.totalCents),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              '${dashboard.paymentCount} payments · '
              '${formatBirr(dashboard.averagePerBucketCents)} avg / $periodLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
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
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MethodChip(
                    icon: Icons.payments_rounded,
                    label: 'Cash',
                    amountCents: cash?.totalCents ?? 0,
                    count: cash?.paymentCount ?? 0,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final int amountCents;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                count == 0 ? '—' : '${formatBirr(amountCents)} ($count)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 240,
          child: _RevenueBarChart(
            buckets: dashboard.buckets,
            period: dashboard.period,
            maxYBirr: (maxCents / 100) * 1.15, // headroom for tooltip
            barColor: scheme.primary,
          ),
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

  String _bottomLabel(DateTime start) => switch (period) {
        DashboardPeriod.day => DateFormat('E').format(start), // Mon, Tue…
        DashboardPeriod.week => DateFormat('M/d').format(start), // Monday
        DashboardPeriod.month => DateFormat('MMM').format(start), // Jan…
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                    _bottomLabel(buckets[index].start),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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
            color: scheme.outlineVariant.withValues(alpha: 0.4),
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
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'No revenue in this period yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a session and take payments — daily, weekly and\n'
              'monthly totals will show up here as bar charts.',
              textAlign: TextAlign.center,
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
