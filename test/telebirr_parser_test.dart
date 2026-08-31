import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/data/sms/telebirr_parser.dart';

void main() {
  group('isFromTelebirr — the anti-spoofing gate', () {
    test('accepts the short code with formatting noise', () {
      expect(isFromTelebirr('127'), isTrue);
      expect(isFromTelebirr(' 127 '), isTrue);
      expect(isFromTelebirr('1-2-7'), isTrue);
    });

    test('rejects everything else', () {
      expect(isFromTelebirr('0911223344'), isFalse); // scammer's phone
      expect(isFromTelebirr('1274'), isFalse); // different short code
      expect(isFromTelebirr('TELEBIRR'), isFalse); // alpha sender
      expect(isFromTelebirr('+251911223344'), isFalse);
      expect(isFromTelebirr(''), isFalse);
      expect(isFromTelebirr(null), isFalse);
    });
  });

  group('parseTelebirrSms — English templates', () {
    test('classic "You have received Birr" template', () {
      const body =
          'You have received Birr 150.00 from ABEBE KEBEDE (0911***234). '
          'Your Telebirr account balance is Birr 2,450.00. '
          'Transaction ID: 881234567890. Thank you for using telebirr!';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 15000);
      expect(p.payerName, 'ABEBE KEBEDE');
      expect(p.payerPhoneMasked, '0911***234');
      expect(p.balanceAfterCents, 245000);
      expect(p.transactionId, '881234567890');
    });

    test('"Received X ETB" template with Trx Id and comma thousands', () {
      const body =
          'Received 1,250.50 ETB from Sara Tesfaye (09** ***234). '
          'Trx Id: 8Z5K2M9XYZ. New Balance: 4,120.00 ETB. 2026-08-31 09:15.';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 125050);
      expect(p.balanceAfterCents, 412000);
      expect(p.transactionId, '8Z5K2M9XYZ');
    });

    test('template without payer phone', () {
      const body =
          'You have received Birr 75.00 from Dawit Haile. '
          'Your balance is Birr 500.00. Transaction ID: 991122334455.';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 7500);
      expect(p.payerName, 'Dawit Haile');
      expect(p.payerPhoneMasked, isNull);
    });
  });

  group('parseTelebirrSms — Amharic templates', () {
    test('ተቀብለዋል template', () {
      const body =
          'ከ ABEBE KEBEDE (0911***234) ብር 150.00 ተቀብለዋል። '
          'የቴሌብር ሂሳብዎ ቀሪ ሂሳብ ብር 2,450.00 ነው። '
          'የግብይት መለያ ቁጥር፦ 881234567890።';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 15000);
      expect(p.payerName, 'ABEBE KEBEDE');
      expect(p.payerPhoneMasked, '0911***234');
      expect(p.balanceAfterCents, 245000);
      expect(p.transactionId, '881234567890');
    });

    test('ገንዘብ ደርሶብዎታል template', () {
      const body =
          'ገንዘብ ደርሶብዎታል! ከ ሰላም ተስፋዬ (09** ***234) ብር 75.00 ተላከ። '
          'ቀሪ ሂሳብዎ ብር 1,200.00 ነው። መለያ ቁጥር፦ 771234567890።';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 7500);
      expect(p.balanceAfterCents, 120000);
      expect(p.transactionId, '771234567890');
    });
  });

  group('parseTelebirrSms — rejections', () {
    test('payment-sent confirmation is not income', () {
      const body =
          'You have sent Birr 150.00 to ABEBE KEBEDE (0911***234). '
          'Transaction ID: 881234567890. Balance: Birr 100.00.';
      expect(parseTelebirrSms(body), isNull);
    });

    test('random SMS from a friend', () {
      const body = 'Hi driver, I am at the gate. 5 minutes!';
      expect(parseTelebirrSms(body), isNull);
    });

    test('message without a transaction id is rejected (cannot dedupe)', () {
      const body =
          'You have received Birr 150.00 from ABEBE KEBEDE (0911***234).';
      expect(parseTelebirrSms(body), isNull);
    });

    test('empty / null bodies', () {
      expect(parseTelebirrSms(null), isNull);
      expect(parseTelebirrSms(''), isNull);
      expect(parseTelebirrSms('   '), isNull);
    });
  });

  group('parseTelebirrSms — amount vs balance disambiguation', () {
    test('balance-first template still picks the payment amount', () {
      const body =
          'Received Birr 200.00 from Mulu Alemu (0911***234). '
          'New balance Birr 900.00. Transaction Id: 551234567890.';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 20000);
      expect(p.balanceAfterCents, 90000);
    });

    test('amount without any balance mentioned', () {
      const body =
          'You have received Birr 300.00 from Genet Wolde. '
          'Transaction ID: 661234567890.';
      final p = parseTelebirrSms(body)!;
      expect(p.amountCents, 30000);
      expect(p.balanceAfterCents, isNull);
    });
  });
}
