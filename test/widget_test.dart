import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_pay/app.dart';

void main() {
  testWidgets('first run shows the onboarding flow', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    await tester.pumpWidget(const TaxiPayApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Taxi Pay'), findsOneWidget);
  });

  testWidgets('returning user goes straight home', (tester) async {
    SharedPreferences.setMockInitialValues(const {'onboarded': true});
    await tester.pumpWidget(const TaxiPayApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Taxi Pay'), findsNothing);
  });
}
