import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/l10n/app_localizations.dart';
import 'package:taxi_pay/widgets/edit_cash_sheet.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester,
      {required void Function(CashEditResult? result) onResult}) async {
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
                  final result =
                      await showCashEditSheet(context, initialCents: 15000);
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

  testWidgets('sheet prefills the current amount and saves edits',
      (tester) async {
    CashEditResult? result;
    await pumpHost(tester, onResult: (r) => result = r);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 15000 cents prefilled exactly as the tile shows it.
    expect(find.widgetWithText(TextField, '150.00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '200');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isA<CashEditSave>());
    expect((result as CashEditSave).cents, 20000);
  });

  testWidgets('delete asks for confirmation first', (tester) async {
    CashEditResult? result;
    await pumpHost(tester, onResult: (r) => result = r);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();

    // Confirmation is up; cancelling keeps the sheet (no result yet).
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    // Confirming pops the sheet with the delete outcome.
    await tester.tap(find.text('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(result, isA<CashEditDelete>());
  });

  testWidgets('save ignores a cleared/invalid field', (tester) async {
    CashEditResult? result;
    await pumpHost(tester, onResult: (r) => result = r);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Sheet stays open, no result — same defensive parse as the add sheet.
    expect(result, isNull);
    expect(find.text('Save'), findsOneWidget);
  });
}
