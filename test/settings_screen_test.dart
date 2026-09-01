import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_pay/l10n/app_localizations.dart';
import 'package:taxi_pay/screens/settings_screen.dart';
import 'package:taxi_pay/services/permissions_service.dart';

/// Channel-free stand-in: the real [PermissionsService] talks to a platform
/// channel that only exists on Android.
class FakePermissions extends PermissionsService {
  FakePermissions({
    this.sms = true,
    this.battery = true,
    this.throwOnCheck = false,
  });

  final bool sms;
  final bool battery;
  final bool throwOnCheck;
  int openSettingsCalls = 0;

  @override
  Future<bool> get isSmsPermissionGranted async {
    if (throwOnCheck) throw Exception('channel unavailable');
    return sms;
  }

  @override
  Future<bool> get isIgnoringBatteryOptimizations async {
    if (throwOnCheck) throw Exception('channel unavailable');
    return battery;
  }

  @override
  Future<void> openAppSettings() async => openSettingsCalls++;
}

void main() {
  Future<void> pumpSettings(
    WidgetTester tester, {
    required FakePermissions permissions,
    String? languageCode,
    ThemeMode themeMode = ThemeMode.system,
    void Function(String? code)? onLanguage,
    void Function(ThemeMode mode)? onTheme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SettingsScreen(
          backup: null,
          languageCode: languageCode,
          onLanguageChanged: (code) async => onLanguage?.call(code),
          themeMode: themeMode,
          onThemeModeChanged: (mode) async => onTheme?.call(mode),
          permissions: permissions,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows live permission statuses with denied reasons',
      (tester) async {
    await pumpSettings(
      tester,
      permissions: FakePermissions(sms: true, battery: false),
    );

    expect(find.text('Granted'), findsOneWidget); // SMS
    expect(find.text('Not granted'), findsOneWidget); // battery
    expect(find.text('Needed for background capture'), findsOneWidget);
    expect(find.text('Needed to capture payments'), findsNothing);
  });

  testWidgets('open-settings button reaches the permissions service',
      (tester) async {
    final permissions = FakePermissions();
    await pumpSettings(tester, permissions: permissions);

    await tester.scrollUntilVisible(
        find.text('Open app settings'), 300);
    // Over-scroll so the button isn't flush with the viewport edge
    // (edge-positioned taps warn and miss).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open app settings'));
    await tester.pumpAndSettle();

    expect(permissions.openSettingsCalls, 1);
  });

  testWidgets('channel failures read as not granted instead of crashing',
      (tester) async {
    await pumpSettings(
      tester,
      permissions: FakePermissions(throwOnCheck: true),
    );

    expect(find.text('Not granted'), findsNWidgets(2));
    expect(find.text('Granted'), findsNothing);
  });

  testWidgets('language and theme choices call back', (tester) async {
    String? language;
    ThemeMode? theme;
    await pumpSettings(
      tester,
      permissions: FakePermissions(),
      onLanguage: (code) => language = code,
      onTheme: (mode) => theme = mode,
    );

    await tester.tap(find.text('አማርኛ'));
    await tester.pumpAndSettle();
    expect(language, 'am');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(theme, ThemeMode.dark);
  });

  testWidgets('the current language and theme come preselected',
      (tester) async {
    await pumpSettings(
      tester,
      permissions: FakePermissions(),
      languageCode: 'en',
      themeMode: ThemeMode.dark,
    );

    // The RadioGroup ancestors hold the selection state.
    final languageGroup =
        tester.widget<RadioGroup<String?>>(find.byType(RadioGroup<String?>));
    expect(languageGroup.groupValue, 'en');
    final themeGroup =
        tester.widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>));
    expect(themeGroup.groupValue, ThemeMode.dark);
  });

  testWidgets('privacy note and version footer are present', (tester) async {
    await pumpSettings(tester, permissions: FakePermissions());

    await tester.scrollUntilVisible(find.text('Private by design'), 200);
    expect(find.text('Private by design'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Taxi Pay v1.0.0'), 200);
    expect(find.text('Taxi Pay v1.0.0'), findsOneWidget);
  });
}
