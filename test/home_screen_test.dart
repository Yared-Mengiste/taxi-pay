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

  /// Real providers over an in-memory DB need real async round-trips; each
  /// sequential sqflite query suspends into the fake-async zone and needs
  /// a real-time window (runAsync) for its response plus a pump to flush
  /// the continuation — so we cycle, which advances the whole chain
  /// (start/stop reload several queries deep).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
  }

  testWidgets('stop asks for confirmation; cancelling keeps the session',
      (tester) async {
    SharedPreferences.setMockInitialValues(const {'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
        TaxiPayApp(settings: SettingsService(prefs), app: app));
    await settle(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await settle(tester);
    // No pumpAndSettle from here on: the live card's elapsed ticker fires
    // every second and would never settle.
    await tester.pump();
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stop this session?'), findsOneWidget);

    // Cancel: the session keeps running.
    await tester.tap(find.text('Keep going'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Stop this session?'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  testWidgets('confirming stop ends the shift and shows the summary',
      (tester) async {
    SharedPreferences.setMockInitialValues(const {'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
        TaxiPayApp(settings: SettingsService(prefs), app: app));
    await settle(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await settle(tester);
    await tester.pump();

    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Stop session'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('Shift finished'), findsOneWidget);
  });
}
