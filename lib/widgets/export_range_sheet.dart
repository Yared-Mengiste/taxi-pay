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
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.exportRangeTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final preset in ExportRangePreset.values)
              ListTile(
                leading: Icon(_presetIcon(preset)),
                title: Text(_presetLabel(preset, sheetL10n)),
                subtitle: preset == ExportRangePreset.allTime
                    ? null
                    // Inclusive display: the [from, to) window shown as
                    // "first day – last day".
                    : Text(_rangeLabel(exportWindowFor(preset, sheetNow))),
                onTap: () => Navigator.of(sheetContext)
                    .pop(exportWindowFor(preset, sheetNow)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: Text(l10n.exportRangeCustom),
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
