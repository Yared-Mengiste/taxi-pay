import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/expense.dart';
import '../util/dates.dart';
import '../util/money.dart';

/// One running cost on the live session feed — money *out*, so the amount
/// renders with a minus sign in the error color, visually opposite to
/// [PaymentTile]'s income rows.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.maybeLocaleOf(context)?.toString();
    final time = formatClock(expense.expenseTimestampMs, locale: locale);
    final isFuel = expense.category == ExpenseCategory.fuel;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: scheme.tertiaryContainer,
        child: Icon(
          isFuel
              ? Icons.local_gas_station_rounded
              : Icons.receipt_long_rounded,
          color: scheme.onTertiaryContainer,
        ),
      ),
      title: Text(
        isFuel ? context.l10n.expenseFuel : context.l10n.expenseOther,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        expense.note == null ? time : '${expense.note} · $time',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '−${formatBirr(expense.amountCents)}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.error,
            ),
      ),
    );
  }
}
