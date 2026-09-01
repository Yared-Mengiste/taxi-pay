import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../providers/session_provider.dart';
import '../util/money.dart';

/// What the user asked the edit sheet to do with a cash entry.
sealed class CashEditResult {
  const CashEditResult();
}

class CashEditSave extends CashEditResult {
  const CashEditSave(this.cents);

  final int cents;
}

class CashEditDelete extends CashEditResult {
  const CashEditDelete();
}

/// Bottom sheet for correcting (or removing) a manually logged cash fare.
///
/// Mirrors the add-cash sheet: same parse-at-the-keyboard rules, prefilled
/// with the current amount. Delete is behind a confirm dialog — it is the
/// one destructive action in the app. Returns null when dismissed.
Future<CashEditResult?> showCashEditSheet(
  BuildContext context, {
  required int initialCents,
}) {
  final controller = TextEditingController(
    // Format through the money util so "15000" cents shows as "150.00",
    // exactly the way the tile displays it — no surprise re-encoding.
    text: formatAmount(initialCents),
  );
  return showModalBottomSheet<CashEditResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final sheetL10n = sheetContext.l10n;
      final scheme = Theme.of(sheetContext).colorScheme;
      int? parseCents() {
        final birr = num.tryParse(controller.text.replaceAll(',', '.'));
        return birr == null ? null : (birr * 100).round();
      }

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
                    Icons.edit_rounded,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sheetL10n.editCashTitle,
                    style:
                        Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sheetL10n.editCashBody,
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
                final cents = parseCents();
                if (cents != null && cents > 0) {
                  Navigator.of(sheetContext).pop(CashEditSave(cents));
                }
              },
              decoration: InputDecoration(
                labelText: sheetL10n.cashAmountLabel,
                prefixText: 'ETB ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final cents = parseCents();
                if (cents != null && cents > 0) {
                  Navigator.of(sheetContext).pop(CashEditSave(cents));
                }
              },
              child: Text(sheetL10n.editCashSave),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final confirmed = await _confirmDelete(sheetContext);
                if (confirmed && sheetContext.mounted) {
                  Navigator.of(sheetContext).pop(const CashEditDelete());
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(sheetContext).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(sheetL10n.editCashDelete),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _confirmDelete(BuildContext sheetContext) async {
  final l10n = sheetContext.l10n;
  final result = await showDialog<bool>(
    context: sheetContext,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.editCashDeleteConfirmTitle),
      content: Text(l10n.editCashDeleteConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.editCashDeleteConfirmCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
            foregroundColor:
                Theme.of(dialogContext).colorScheme.onErrorContainer,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.editCashDeleteConfirmAction),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Convenience wrapper: shows the sheet and applies the result to the
/// running session. The provider is captured before the await (step 8's
/// async-gap rule, same as [promptAndAddCash]).
Future<void> promptAndEditCash(
  BuildContext context, {
  required Payment payment,
}) async {
  final session = context.read<SessionProvider>();
  final result = await showCashEditSheet(
    context,
    initialCents: payment.amountCents,
  );
  if (result == null) return;
  switch (result) {
    case CashEditSave(:final cents):
      await session.updateCash(payment: payment, amountCents: cents);
    case CashEditDelete():
      await session.deleteCash(payment: payment);
  }
}
