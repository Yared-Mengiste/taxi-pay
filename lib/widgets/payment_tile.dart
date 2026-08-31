import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../util/dates.dart';
import '../util/money.dart';

/// One row on the live session list: amount, payer, time, method.
///
/// Cash entries are the only user-authored rows, so they're the only ones
/// with an edit affordance ([onEdit]); teleBirr rows are receipts and stay
/// read-only.
class PaymentTile extends StatelessWidget {
  const PaymentTile({super.key, required this.payment, this.onEdit});

  final Payment payment;

  /// Opens the edit sheet when tapped; null on teleBirr rows.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final time = formatClock(payment.smsTimestampMs, locale: locale);
    final isCash = payment.method == PaymentMethod.cash;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      onTap: onEdit,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatBirr(payment.amountCents),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit_rounded, size: 18, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    );
  }
}
