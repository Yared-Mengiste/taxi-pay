import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../services/simulation_service.dart';

/// Bottom sheet for firing a test teleBirr payment through the real
/// capture pipeline (see [SimulationService]).
///
/// Mirrors the cash sheet: same keyboard-level amount validation, same
/// "sheet returns, caller acts" spirit — except here the pipeline runs
/// inside the sheet because the result (captured or not) is what the
/// user needs feedback about.
Future<void> showSimulatePaymentSheet(
  BuildContext context, {
  required SimulationService simulation,
}) {
  final l10n = context.l10n;
  final amount = TextEditingController(text: '120');
  final payer = TextEditingController(text: 'Abebe Balcha');
  final phone = TextEditingController(text: '09** ***234');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      int? parseCents() {
        final birr = num.tryParse(amount.text.replaceAll(',', '.'));
        return birr == null ? null : (birr * 100).round();
      }

      return Padding(
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
            Text(l10n.simulateSheetTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              l10n.simulateSheetBody,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,7}([.,]\d{0,2})?')),
              ],
              decoration: InputDecoration(
                labelText: l10n.cashAmountLabel,
                border: const OutlineInputBorder(),
                prefixText: 'ETB ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: payer,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.simulatePayerLabel,
                hintText: l10n.simulatePayerHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.simulatePhoneLabel,
                hintText: l10n.simulatePhoneHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: amount,
              builder: (context, _) => FilledButton.icon(
                // Enabled only for a parseable positive amount — the same
                // rule the expense sheet applies.
                onPressed: (parseCents() ?? 0) > 0
                    ? () => _send(sheetContext, simulation, parseCents()!,
                        payerName: payer.text, payerPhone: phone.text)
                    : null,
                icon: const Icon(Icons.science_outlined),
                label: Text(l10n.simulateSend),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _send(
  BuildContext sheetContext,
  SimulationService simulation,
  int amountCents, {
  required String payerName,
  required String payerPhone,
}) async {
  // Messenger, navigator and strings captured before the await — the sheet
  // is gone by the time the capture pipeline and the snackbar land.
  final messenger = ScaffoldMessenger.of(sheetContext);
  final navigator = Navigator.of(sheetContext);
  final l10n = sheetContext.l10n;
  final doneMessage = l10n.simulateDone;
  final droppedMessage = l10n.simulateDropped;
  Payment? captured;
  try {
    captured = await simulation.sendTestPayment(
      amountCents: amountCents,
      payerName: payerName,
      payerPhone: payerPhone,
    );
  } finally {
    navigator.pop();
  }
  messenger.showSnackBar(SnackBar(
    content: Text(captured != null ? doneMessage : droppedMessage),
  ));
}
