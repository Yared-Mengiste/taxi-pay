/// Result of successfully parsing a teleBirr "payment received" SMS body.
class TelebirrPayment {
  const TelebirrPayment({
    required this.transactionId,
    required this.amountCents,
    this.payerName,
    this.payerPhoneMasked,
    this.balanceAfterCents,
  });

  final String transactionId;
  final int amountCents;

  /// Sender name as teleBirr prints it (may be Latin or Ethiopic script).
  final String? payerName;

  /// Masked payer phone exactly as printed, e.g. `09** ***234`.
  final String? payerPhoneMasked;

  /// Wallet balance after the payment, if the SMS includes it.
  final int? balanceAfterCents;

  double get amountBirr => amountCents / 100.0;
}

/// teleBirr's official short code. Payments arrive from this address only.
const String telebirrShortCode = '127';

/// Strict check that an SMS **sender address** is teleBirr's short code.
///
/// This is the anti-spoofing gate and MUST run on the PDU sender address
/// (what the carrier delivered), never on message text: anyone can type
/// "Transaction ID: 123456789" into an SMS body, but only the carrier can
/// set the originator to 127. Normalization strips formatting noise so
/// `"127"`, `" 127 "` etc. pass; everything else (full numbers, alpha
/// senders) is rejected.
bool isFromTelebirr(String? address) {
  if (address == null) return false;
  final digits = address.replaceAll(RegExp(r'[^0-9]'), '');
  return digits == telebirrShortCode;
}

// Received-money signal words. A message must contain one of these to even be
// considered — "you have sent" confirmations, balance checks, promos etc. are
// all rejected here.
final RegExp _receivedSignal = RegExp(
  r'received|ተቀብለዋል|ደርሶብዎታል|ደርሶብናል|ገንዘብ ደርሶ',
  caseSensitive: false,
);

// Balance keywords: EN + Amharic ("ቀሪ ሂሳብ" = remaining balance).
final RegExp _balanceKeyword = RegExp(
  r'balance|ቀሪ\s*ሂሳብ',
  caseSensitive: false,
);

// A currency-attached amount, either order: "Birr 150.00", "150.00 ETB",
// "ብር 150.00", "150.00 ብር". Group 1 = number when currency leads,
// group 2 = number when currency trails (currency stays OUTSIDE the groups so
// the captured text is a plain parseable number).
final RegExp _currencyAmount = RegExp(
  r'(?:(?:ETB|Birr|ብር)\s*(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?))'
  r'|(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\s*(?:ETB|Birr|ብር)',
  caseSensitive: false,
);

// Transaction id: "Transaction ID: 881234567890", "Trx Id 8Z5K2M9XYZ",
// Amharic "የግብይት መለያ ቁጥር፦ 881234567890".
final RegExp _transactionId = RegExp(
  r'(?:transaction|trx|ref(?:erence)?)\s*[.\s]*id[^\dA-Za-z]{0,5}([0-9A-Za-z]{8,24})'
  r'|መለያ\s*ቁጥር[^\dA-Za-z]{0,5}([0-9A-Za-z]{8,24})',
  caseSensitive: false,
);

// Payer: "from FULL NAME (09** ***234)" / "ከ FULL NAME (0911***234)".
// Phone group is digits, stars, dots, spaces and dashes only.
final RegExp _payerWithPhone = RegExp(
  r"(?:from|ከ)\s+([A-Za-z\u1200-\u137F][A-Za-z\u1200-\u137F.'’\- ]{0,40}?)\s*"
  r'\(([0-9*\s.\-]{4,20})\)',
  caseSensitive: false,
);

// Payer without a phone in parens (some templates omit it).
final RegExp _payerNameOnly = RegExp(
  r"(?:from|ከ)\s+([A-Za-z\u1200-\u137F][A-Za-z\u1200-\u137F.'’\- ]{0,40}?)"
  r'(?=[,.]|\s\s|$)',
  caseSensitive: false,
);

int? _parseCents(String raw) {
  final n = num.tryParse(raw.replaceAll(',', ''));
  if (n == null || n <= 0) return null;
  return (n * 100).round();
}

class _AmountMatch {
  const _AmountMatch(this.cents, this.start, this.end);
  final int cents;
  final int start;
  final int end;
}

List<_AmountMatch> _findAmounts(String body) {
  return [
    for (final m in _currencyAmount.allMatches(body))
      () {
        final raw = m.group(1) ?? m.group(2);
        final cents = raw == null ? null : _parseCents(raw);
        return cents == null ? null : _AmountMatch(cents, m.start, m.end);
      }()
  ].whereType<_AmountMatch>().toList();
}

/// Parses a teleBirr "payment received" SMS body.
///
/// Returns null when the message is not a received-payment confirmation, or
/// is missing the amount / transaction id — without a transaction id we
/// cannot dedupe, so a partial parse is worse than no parse.
///
/// Amounts vs. balance: templates mention two amounts (payment + resulting
/// balance). The balance keyword is located first and the currency-attached
/// number nearest *after* it is consumed as the balance; the first remaining
/// amount is the payment.
TelebirrPayment? parseTelebirrSms(String? body) {
  if (body == null || body.trim().isEmpty) return null;
  if (!_receivedSignal.hasMatch(body)) return null;

  var working = body;
  int? balanceCents;

  // 1) Try to peel off the balance amount.
  final balanceKw = _balanceKeyword.firstMatch(working);
  if (balanceKw != null) {
    final after = working.substring(balanceKw.end);
    final near = _findAmounts(after).firstOrNull;
    if (near != null && near.start <= 80) {
      balanceCents = near.cents;
      // Remove the balance amount from the original string so it cannot be
      // mistaken for the payment amount. Translate the offset back.
      final removeStart = balanceKw.end + near.start;
      working = working.replaceRange(
          removeStart, balanceKw.end + near.end, ' ' * (near.end - near.start));
    }
  }

  // 2) The payment amount is the first currency-attached amount left.
  final amounts = _findAmounts(working);
  if (amounts.isEmpty) return null;
  final amountCents = amounts.first.cents;

  // 3) Transaction id — mandatory.
  final txMatch = _transactionId.firstMatch(body);
  final txId = txMatch?.group(1) ?? txMatch?.group(2);
  if (txId == null) return null;

  // 4) Payer, optional.
  final payerMatch = _payerWithPhone.firstMatch(body);
  String? payerName;
  String? payerPhone;
  if (payerMatch != null) {
    payerName = payerMatch.group(1)?.trim();
    payerPhone = payerMatch.group(2)?.trim();
  } else {
    payerName = _payerNameOnly.firstMatch(body)?.group(1)?.trim();
  }

  return TelebirrPayment(
    transactionId: txId.toUpperCase(),
    amountCents: amountCents,
    payerName: (payerName == null || payerName.isEmpty) ? null : payerName,
    payerPhoneMasked: (payerPhone == null || payerPhone.isEmpty) ? null : payerPhone,
    balanceAfterCents: balanceCents,
  );
}
