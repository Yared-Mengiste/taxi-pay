import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/l10n/app_localizations.dart';
import 'package:taxi_pay/widgets/add_cash_sheet.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester,
      {required void Function(int? cents) onResult}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showCashEntrySheet(context);
                  onResult(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('quick-amount chips enter the fare in one tap', (tester) async {
    int? cents;
    await pumpHost(tester, onResult: (c) => cents = c);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // One tap on a common fare IS the entry — no second tap on Add.
    await tester.tap(find.text('50'));
    await tester.pumpAndSettle();

    expect(cents, 5000);
  });

  testWidgets('typing a custom amount still works', (tester) async {
    int? cents;
    await pumpHost(tester, onResult: (c) => cents = c);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '75.5');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(cents, 7550);
  });
}
