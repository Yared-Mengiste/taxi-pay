import 'expense.dart';
import 'payment.dart';

/// One row of the live session feed: either a payment or an expense.
///
/// A small sealed union instead of a shared base class — payments and
/// expenses are *not* the same concept (one adds, one subtracts), they
/// just share a timeline. Exhaustive `switch` keeps tile rendering honest.
sealed class FeedItem {
  const FeedItem();

  factory FeedItem.payment(Payment payment) = FeedPayment;

  factory FeedItem.expense(Expense expense) = FeedExpense;

  /// Sort key for the merged, newest-first feed.
  int get timestampMs;
}

class FeedPayment extends FeedItem {
  const FeedPayment(this.payment);

  final Payment payment;

  @override
  int get timestampMs => payment.smsTimestampMs;
}

class FeedExpense extends FeedItem {
  const FeedExpense(this.expense);

  final Expense expense;

  @override
  int get timestampMs => expense.expenseTimestampMs;
}
