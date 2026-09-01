import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../util/dates.dart';

/// Bottom sheet that picks *what* to export: a preset window (this/last
/// week, this/last month, rolling 7/30 days, everything) or a custom
/// from–to pair.
///
/// Returns the chosen `[from, to)` window, or null when dismissed. The
/// window math itself lives in [exportWindowFor] — this sheet only draws
/// choices and runs date pickers.
Future<(DateTime, DateTime)?> showExportRangeSheet(BuildContext context) {
  final l10n = context.l10n;
  final now = DateTime.now();
  return showModalBottomSheet<(DateTime, DateTime)>(
    context: context,
    builder: (sheetContext) {
      final sheetL10n = sheetContext.l10n;
      final sheetNow = now;
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.ios_share_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.exportRangeTitle,
                    style:
                        Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                            ),
                  ),
                ],
              ),
            ),
            for (final preset in ExportRangePreset.values)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _presetIcon(preset),
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  _presetLabel(preset, sheetL10n),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: preset == ExportRangePreset.allTime
                    ? null
                    // Inclusive display: the [from, to) window shown as
                    // "first day – last day".
                    : Text(_rangeLabel(exportWindowFor(preset, sheetNow))),
                onTap: () => Navigator.of(sheetContext)
                    .pop(exportWindowFor(preset, sheetNow)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Divider(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              title: Text(
                l10n.exportRangeCustom,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              onTap: () => _pickCustomRange(sheetContext),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Two sequential date pickers; the chosen window is end-day inclusive
/// (converted to an exclusive upper bound). A reversed selection is
/// normalized rather than rejected — the intent is obvious either way.
Future<void> _pickCustomRange(BuildContext sheetContext) async {
  // Captured before the awaits: the navigator and strings outlive the
  // pickers even if the sheet is somehow gone by the end.
  final l10n = sheetContext.l10n;
  final navigator = Navigator.of(sheetContext);
  final bounds = (
    first: DateTime(2020),
    last: DateTime.now().add(const Duration(days: 1)),
  );
  final first = await showDatePicker(
    context: sheetContext,
    helpText: l10n.exportPickStartDate,
    initialDate: DateTime.now(),
    firstDate: bounds.first,
    lastDate: bounds.last,
  );
  if (first == null) return;
  // The sheet stays open under the pickers, so this should always hold —
  // but a popped-early sheet must not crash the second picker.
  if (!sheetContext.mounted) return;
  final second = await showDatePicker(
    context: sheetContext,
    helpText: l10n.exportPickEndDate,
    initialDate: first,
    firstDate: bounds.first,
    lastDate: bounds.last,
  );
  if (second == null) return;

  var from = startOfDay(first);
  var to = startOfDay(second).add(const Duration(days: 1));
  if (from.isAfter(to)) {
    (from, to) = (to, from);
  }
  navigator.pop((from, to));
}

IconData _presetIcon(ExportRangePreset preset) => switch (preset) {
      ExportRangePreset.thisWeek ||
      ExportRangePreset.lastWeek =>
        Icons.calendar_view_week_rounded,
      ExportRangePreset.thisMonth ||
      ExportRangePreset.lastMonth =>
        Icons.calendar_month_rounded,
      ExportRangePreset.last7Days ||
      ExportRangePreset.last30Days => Icons.today_rounded,
      ExportRangePreset.allTime => Icons.all_inclusive_rounded,
    };

String _presetLabel(ExportRangePreset preset, AppLocalizations l10n) =>
    switch (preset) {
      ExportRangePreset.thisWeek => l10n.exportRangeThisWeek,
      ExportRangePreset.lastWeek => l10n.exportRangeLastWeek,
      ExportRangePreset.thisMonth => l10n.exportRangeThisMonth,
      ExportRangePreset.lastMonth => l10n.exportRangeLastMonth,
      ExportRangePreset.last7Days => l10n.exportRangeLast7Days,
      ExportRangePreset.last30Days => l10n.exportRangeLast30Days,
      ExportRangePreset.allTime => l10n.exportRangeAllTime,
    };

String _rangeLabel((DateTime, DateTime) window) {
  final (from, to) = window;
  final lastInclusive = to.subtract(const Duration(milliseconds: 1));
  final fromLabel = _dayFormat.format(from);
  final toLabel = _dayFormat.format(lastInclusive);
  return fromLabel == toLabel ? fromLabel : '$fromLabel – $toLabel';
}

final _dayFormat = DateFormat('MMM d, y');
