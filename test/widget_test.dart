import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/app.dart';

void main() {
  testWidgets('placeholder app renders', (tester) async {
    await tester.pumpWidget(const TaxiPayApp());
    expect(find.text('Taxi Pay'), findsOneWidget);
  });
}
