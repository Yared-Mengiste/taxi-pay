import 'package:intl/intl.dart';

final NumberFormat _amountFormat = NumberFormat('#,##0.00', 'en_US');

/// `15000` cents -> `150.00` (grouping, always 2 decimals).
String formatAmount(int cents) => _amountFormat.format(cents / 100.0);

/// `15000` cents -> `ETB 150.00` (or `1,500 ብር` style symbols by locale
/// choice; the symbol is passed in by the caller so localization owns it).
String formatBirr(int cents, {String symbol = 'ETB'}) =>
    '$symbol ${formatAmount(cents)}';
