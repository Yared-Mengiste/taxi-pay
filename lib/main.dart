import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/db/app_database.dart';
import 'services/settings_service.dart';

/// Async bootstrap lives here, not inside a widget: by the time the first
/// widget builds, settings and the database already exist and can be handed
/// down as plain constructor arguments. Widget tests can therefore inject an
/// in-memory database with zero mocking gymnastics.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsService(await SharedPreferences.getInstance());
  final app = await AppDatabase.openDefault();
  runApp(TaxiPayApp(settings: settings, app: app));
}
