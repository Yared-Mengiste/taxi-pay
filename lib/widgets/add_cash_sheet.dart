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
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.cashSheetTitle,
              style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.cashSheetBody,
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
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
              border: const OutlineInputBorder(),
              prefixText: 'ETB ',
            ),
          ),
          const SizedBox(height: 16),
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
    ),
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
