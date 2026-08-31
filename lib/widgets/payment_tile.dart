import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../util/dates.dart';
import '../util/money.dart';

/// One row on the live session list: amount, payer, time, method.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final time = formatClock(payment.smsTimestampMs, locale: locale);
    final isCash = payment.method == PaymentMethod.cash;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: isCash
          ? CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(Icons.payments_outlined,
                  color: scheme.onSecondaryContainer),
            )
          : CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.phone_iphone_rounded,
                  color: scheme.onPrimaryContainer),
            ),
      title: Text(
        isCash
            ? context.l10n.cashFare
            : (payment.payerName ?? context.l10n.telebirrPayment),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isCash
            ? time
            : '${payment.payerPhone ?? '•••'} · $time',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatBirr(payment.amountCents),
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
