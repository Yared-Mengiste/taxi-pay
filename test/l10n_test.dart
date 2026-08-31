import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/l10n/app_localizations.dart';

void main() {
  testWidgets('Amharic strings load and render for the am locale',
      (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('am'),
        builder: (context, _) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    final l10n = AppLocalizations.of(captured);
    expect(l10n.homeStart, 'ጀምር');
    expect(l10n.actionStop, 'አቁም');
    expect(l10n.navDashboard, 'ሪፖርት');
  });

  testWidgets('English plural forms behave', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        builder: (context, _) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    final l10n = AppLocalizations.of(captured);
    expect(l10n.paymentsCount(1), '1 payment');
    expect(l10n.paymentsCount(5), '5 payments');
    expect(l10n.paymentsCount(3), isNot(contains('payment this')));
  });

  testWidgets('Amharic plurals use the single other form', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('am'),
        builder: (context, _) {
          captured = context;
          return const SizedBox();
        },
      ),
    );
    final l10n = AppLocalizations.of(captured);
    expect(l10n.paymentsCount(1), '1 ክፍያ');
    expect(l10n.paymentsCount(5), '5 ክፍያ');
  });
}
