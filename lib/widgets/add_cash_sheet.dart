import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/session_provider.dart';

/// Bottom sheet for logging a cash fare into the running session.
///
/// Returns the entered amount in cents (or null if dismissed).
Future<int?> showCashEntrySheet(BuildContext context) {
  final l10n = context.l10n;
  final controller = TextEditingController();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.cashSheetTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cashSheetBody,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}([.,]\d{0,2})?')),
              ],
              onSubmitted: (value) {
                final birr = num.tryParse(value.replaceAll(',', '.'));
                Navigator.of(sheetContext)
                    .pop(birr == null ? null : (birr * 100).round());
              },
              decoration: InputDecoration(
                labelText: l10n.cashAmountLabel,
                hintText: l10n.cashAmountHint,
                prefixText: 'ETB ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Common fares, one tap: filling the field would still need a
            // second tap on Add, so a chip *is* the entry.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final birr in const [20, 30, 50, 100, 150, 200])
                  ActionChip(
                    avatar: Icon(Icons.add_rounded,
                        size: 16, color: scheme.primary),
                    label: Text(
                      '$birr',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    backgroundColor: scheme.surfaceContainerHigh,
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(birr * 100),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final birr = num.tryParse(controller.text.replaceAll(',', '.'));
                Navigator.of(sheetContext)
                    .pop(birr == null ? null : (birr * 100).round());
              },
              child: Text(l10n.cashAdd),
            ),
          ],
        ),
      );
    },
  );
}

/// Convenience wrapper: shows the sheet and adds the fare if one was entered.
Future<void> promptAndAddCash(BuildContext context) async {
  final session = context.read<SessionProvider>();
  final cents = await showCashEntrySheet(context);
  if (cents != null && cents > 0) {
    await session.addCash(amountCents: cents);
  }
}
