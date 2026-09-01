import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../models/expense.dart';
import '../providers/session_provider.dart';

/// What the expense sheet collected — a tiny value object so the wrapper
/// applies one write to the provider.
class ExpenseDraft {
  const ExpenseDraft({
    required this.amountCents,
    required this.category,
    this.note,
  });

  final int amountCents;
  final ExpenseCategory category;
  final String? note;
}

/// Bottom sheet for logging a running cost (fuel by default) into the
/// running session. Mirrors [showCashEntrySheet]: parse-once validation at
/// the keyboard, sheet returns data, wrapper writes to the provider.
Future<ExpenseDraft?> showExpenseEntrySheet(BuildContext context) {
  final controller = TextEditingController();
  final noteController = TextEditingController();
  final state = ValueNotifier<ExpenseCategory>(ExpenseCategory.fuel);
  return showModalBottomSheet<ExpenseDraft>(
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
                    color: scheme.errorContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.local_gas_station_rounded,
                    size: 20,
                    color: scheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sheetContext.l10n.expenseSheetTitle,
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
              sheetContext.l10n.expenseSheetBody,
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
              decoration: InputDecoration(
                labelText: sheetContext.l10n.cashAmountLabel,
                hintText: sheetContext.l10n.cashAmountHint,
                prefixText: 'ETB ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.error,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<ExpenseCategory>(
              valueListenable: state,
              builder: (sheetContext, category, _) => SegmentedButton(
                segments: [
                  ButtonSegment(
                    value: ExpenseCategory.fuel,
                    icon: const Icon(Icons.local_gas_station_rounded),
                    label: Text(sheetContext.l10n.expenseFuel),
                  ),
                  ButtonSegment(
                    value: ExpenseCategory.other,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(sheetContext.l10n.expenseOther),
                  ),
                ],
                selected: {category},
                onSelectionChanged: (selection) =>
                    state.value = selection.first,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: sheetContext.l10n.expenseNoteLabel,
                hintText: sheetContext.l10n.expenseNoteHint,
              ),
            ),
            const SizedBox(height: 24),
            ListenableBuilder(
              listenable: controller,
              builder: (sheetContext, _) {
                final birr =
                    num.tryParse(controller.text.replaceAll(',', '.'));
                final enabled = birr != null && birr > 0;
                return FilledButton(
                  onPressed: enabled
                      ? () {
                          // Blank notes collapse to null here so the draft
                          // is already clean data for the repository.
                          final note = noteController.text.trim();
                          Navigator.of(sheetContext).pop(ExpenseDraft(
                            amountCents: (birr * 100).round(),
                            category: state.value,
                            note: note.isEmpty ? null : note,
                          ));
                        }
                      : null,
                  child: Text(sheetContext.l10n.cashAdd),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Convenience wrapper: shows the sheet and logs the expense if one was
/// entered. Provider captured before the await, per the async-gap rule.
Future<void> promptAndAddExpense(BuildContext context) async {
  final session = context.read<SessionProvider>();
  final draft = await showExpenseEntrySheet(context);
  if (draft != null && draft.amountCents > 0) {
    await session.addExpense(
      amountCents: draft.amountCents,
      category: draft.category,
      note: draft.note,
    );
  }
}
