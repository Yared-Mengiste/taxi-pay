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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCash
                        ? scheme.secondaryContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    isCash
                        ? Icons.payments_rounded
                        : Icons.phone_iphone_rounded,
                    size: 22,
                    color: isCash
                        ? scheme.onSecondaryContainer
                        : scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCash
                            ? context.l10n.cashFare
                            : (payment.payerName ?? context.l10n.telebirrPayment),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (!isCash && payment.payerPhone != null) ...[
                            Text(
                              payment.payerPhone!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              ' · ',
                              style: TextStyle(color: scheme.outlineVariant),
                            ),
                          ],
                          Text(
                            time,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatBirr(payment.amountCents),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isCash ? scheme.onSurface : scheme.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
