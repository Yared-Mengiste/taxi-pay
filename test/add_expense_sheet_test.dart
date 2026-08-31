import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/l10n/app_localizations.dart';
import 'package:taxi_pay/models/expense.dart';
import 'package:taxi_pay/widgets/add_expense_sheet.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester,
      {required void Function(ExpenseDraft? draft) onResult}) async {
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
                  final draft = await showExpenseEntrySheet(context);
                  onResult(draft);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('defaults to fuel; add returns the draft', (tester) async {
    ExpenseDraft? draft;
    await pumpHost(tester, onResult: (d) => draft = d);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Fuel is preselected.
    await tester.enterText(find.byType(TextField).first, '650.50');
    await tester.enterText(find.byType(TextField).last, 'full tank');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(draft, isNotNull);
    expect(draft!.amountCents, 65050);
    expect(draft!.category, ExpenseCategory.fuel);
    expect(draft!.note, 'full tank');
  });

  testWidgets('switching to Other carries through', (tester) async {
    ExpenseDraft? draft;
    await pumpHost(tester, onResult: (d) => draft = d);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(draft!.category, ExpenseCategory.other);
    expect(draft!.note, isNull); // blank note collapses to null
  });

  testWidgets('Add stays disabled until an amount is typed', (tester) async {
    await pumpHost(tester, onResult: (_) => fail('no result expected'));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'Add');
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

    // Zero isn't a real expense either.
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.pump();
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '12');
    await tester.pump();
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
  });
}
