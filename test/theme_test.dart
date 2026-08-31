import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taxi_pay/app.dart';
import 'package:taxi_pay/data/db/app_database.dart';
import 'package:taxi_pay/services/settings_service.dart';
import 'package:taxi_pay/theme/app_theme.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('themes are teal-seeded with the warm cash accent', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    // Same seed on both variants — identity doesn't flip with the theme.
    expect(light.colorScheme.primary, isNot(dark.colorScheme.primary));
    // Cash accent is applied as secondary in both variants.
    expect(light.colorScheme.secondary, AppTheme.cashAccent);
    expect(dark.colorScheme.secondary, AppTheme.cashAccent);
  });

  late AppDatabase app;

  setUp(() async {
    // Opened in setUp, NOT inside the testWidgets body: ffi isolate
    // round-trips awaited directly in a fake-async zone never complete
    // (same reason widget_test.dart opens its DB here).
    app = await AppDatabase.openInMemory();
  });

  tearDown(() async {
    await app.db.close();
  });

  testWidgets('saved theme_mode=dark is honored on launch', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'onboarded': true, 'theme_mode': 'dark'});
    final prefs = await SharedPreferences.getInstance();

    // Config assertions only — no settling needed, so no runAsync dance:
    // MaterialApp's widget properties are readable straight after a pump,
    // whatever the providers are still loading underneath.
    await tester.pumpWidget(
        TaxiPayApp(settings: SettingsService(prefs), app: app));
    // Let the providers' real ffi loads finish before tearDown closes the
    // DB — otherwise the in-flight query throws into the completed test.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    final materialApp =
        tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(materialApp.darkTheme!.colorScheme.brightness, Brightness.dark);
  });
}
