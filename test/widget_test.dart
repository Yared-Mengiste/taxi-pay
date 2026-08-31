import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/app.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/services/settings_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase app;

  setUp(() async {
    app = await AppDatabase.openInMemory();
  });

  tearDown(() async {
    await app.db.close();
  });

  testWidgets('first run shows the onboarding flow', (tester) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
        TaxiPayApp(settings: SettingsService(prefs), app: app));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Taxi Pay'), findsOneWidget);
  });

  testWidgets('returning user goes straight home', (tester) async {
    SharedPreferences.setMockInitialValues(const {'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
        TaxiPayApp(settings: SettingsService(prefs), app: app));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Taxi Pay'), findsNothing);
    expect(find.text('Taxi Pay'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}
