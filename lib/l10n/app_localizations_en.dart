// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navSession => 'Session';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navSettings => 'Settings';

  @override
  String get homeStart => 'START';

  @override
  String get homeIdleHint =>
      'Ready to work? Start a session to track teleBirr payments.';

  @override
  String get shiftFinished => 'Shift finished';

  @override
  String get recentRoutes => 'Recent routes';

  @override
  String paymentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '$count payment',
    );
    return '$_temp0';
  }

  @override
  String liveSince(Object time) {
    return 'LIVE · since $time';
  }

  @override
  String paymentsThisSession(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments this session',
      one: '$count payment this session',
    );
    return '$_temp0';
  }

  @override
  String get actionCash => 'Cash';

  @override
  String get actionStop => 'Stop';

  @override
  String get cashFare => 'Cash fare';

  @override
  String get telebirrPayment => 'teleBirr payment';

  @override
  String walletBalance(Object amount) {
    return 'Wallet: $amount';
  }

  @override
  String get syncTooltip => 'Sync missed SMS';

  @override
  String syncRecovered(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count missed payments from your inbox.',
      one: 'Synced $count missed payment from your inbox.',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'All payments are up to date.';

  @override
  String get syncFailed =>
      'Couldn\'t read the SMS inbox — check the SMS permission.';

  @override
  String get stopConfirmTitle => 'Stop this session?';

  @override
  String get stopConfirmBody =>
      'The shift summary stays on the home screen, and the session moves to the dashboard\'s past sessions.';

  @override
  String get stopConfirmAction => 'Stop session';

  @override
  String get stopConfirmCancel => 'Keep going';

  @override
  String get simulateTooltip => 'Send a test payment';

  @override
  String get simulateSheetTitle => 'Send a test payment';

  @override
  String get simulateSheetBody =>
      'Builds a realistic teleBirr SMS and runs it through the real capture pipeline. No money moves — it only tests the app.';

  @override
  String get simulatePayerLabel => 'Payer name';

  @override
  String get simulatePayerHint => 'e.g. Abebe Balcha';

  @override
  String get simulatePhoneLabel => 'Payer phone';

  @override
  String get simulatePhoneHint => 'e.g. 09** ***234';

  @override
  String get simulateSend => 'Send test SMS';

  @override
  String get simulateDone => 'Test payment captured.';

  @override
  String get simulateDropped => 'Nothing was captured — is a session running?';

  @override
  String get sessionsTitle => 'Past sessions';

  @override
  String get sessionNoPayments => 'No payments in this session.';

  @override
  String get actionFuel => 'Fuel';

  @override
  String get expenseFuel => 'Fuel';

  @override
  String get expenseOther => 'Other';

  @override
  String get expenseSheetTitle => 'Add an expense';

  @override
  String get expenseSheetBody =>
      'Fuel and other running costs are subtracted from the session\'s net earnings.';

  @override
  String get expenseNoteLabel => 'Note (optional)';

  @override
  String get expenseNoteHint => 'e.g. full tank';

  @override
  String expensesLabel(Object amount) {
    return 'Expenses: $amount';
  }

  @override
  String netLabel(Object amount) {
    return 'Net: $amount';
  }

  @override
  String get cashSheetTitle => 'Add a cash fare';

  @override
  String get cashSheetBody =>
      'Cash fares join the same session total as teleBirr payments.';

  @override
  String get cashAmountLabel => 'Amount in birr';

  @override
  String get cashAmountHint => 'e.g. 150';

  @override
  String get cashAdd => 'Add';

  @override
  String get editCashTitle => 'Edit cash fare';

  @override
  String get editCashBody =>
      'Correct the amount, or delete this entry if it was a mistake.';

  @override
  String get editCashSave => 'Save';

  @override
  String get editCashDelete => 'Delete entry';

  @override
  String get editCashDeleteConfirmTitle => 'Delete this entry?';

  @override
  String get editCashDeleteConfirmBody =>
      'It will be removed from the session total. This can\'t be undone.';

  @override
  String get editCashDeleteConfirmAction => 'Delete';

  @override
  String get editCashDeleteConfirmCancel => 'Cancel';

  @override
  String get feedWaitingTitle => 'Waiting for teleBirr payments…';

  @override
  String get feedWaitingBody =>
      'Payments sent to your phone appear here instantly.\nPassengers paying cash? Log it below.';

  @override
  String get feedAddCash => 'Add cash fare';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageAmharic => 'አማርኛ';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsPermissionsTitle => 'Permissions';

  @override
  String get settingsDataTitle => 'Data';

  @override
  String get settingsPermissionSms => 'SMS access (teleBirr 127)';

  @override
  String get settingsPermissionSmsDenied => 'Needed to capture payments';

  @override
  String get settingsPermissionBattery => 'Exempt from battery optimization';

  @override
  String get settingsPermissionBatteryDenied => 'Needed for background capture';

  @override
  String get settingsGranted => 'Granted';

  @override
  String get settingsDenied => 'Not granted';

  @override
  String get settingsOpenAppSettings => 'Open app settings';

  @override
  String get settingsPrivacyTitle => 'Private by design';

  @override
  String get settingsPrivacyBody =>
      'Everything stays on this phone. Only teleBirr confirmations from 127 are read — no account, no upload.';

  @override
  String get settingsVersion => 'Taxi Pay v1.0.0';

  @override
  String get backupAction => 'Export backup';

  @override
  String get backupSubtitle => 'Share a copy of all your data as one file';

  @override
  String get backupDone => 'Backup ready — choose where to keep it.';

  @override
  String get backupFailed => 'Backup failed. Try again.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get periodDaily => 'Daily';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get window7Days => 'Last 7 days';

  @override
  String get window8Weeks => 'Last 8 weeks';

  @override
  String get window12Months => 'Last 12 months';

  @override
  String get perDay => 'day';

  @override
  String get perWeek => 'week';

  @override
  String get perMonth => 'month';

  @override
  String avgPerPeriod(Object amount, Object period) {
    return '$amount avg / $period';
  }

  @override
  String get dashboardEmptyTitle => 'No revenue in this period yet';

  @override
  String get dashboardEmptyBody =>
      'Start a session and take payments — daily, weekly and\nmonthly totals will show up here as bar charts.';

  @override
  String get exportTooltip => 'Export CSV';

  @override
  String get exportEmpty => 'No payments in this period to export.';

  @override
  String exportDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported $count payments as CSV.',
      one: 'Exported $count payment as CSV.',
    );
    return '$_temp0';
  }

  @override
  String get exportRangeTitle => 'Export which period?';

  @override
  String get exportRangeThisWeek => 'This week';

  @override
  String get exportRangeLastWeek => 'Last week';

  @override
  String get exportRangeThisMonth => 'This month';

  @override
  String get exportRangeLastMonth => 'Last month';

  @override
  String get exportRangeLast7Days => 'Last 7 days';

  @override
  String get exportRangeLast30Days => 'Last 30 days';

  @override
  String get exportRangeAllTime => 'Everything';

  @override
  String get exportRangeCustom => 'Custom range…';

  @override
  String get exportPickStartDate => 'Start date';

  @override
  String get exportPickEndDate => 'End date';

  @override
  String get onbWelcomeTitle => 'Welcome to Taxi Pay';

  @override
  String get onbWelcomeBody =>
      'Track the teleBirr payments passengers send you during a shift, plus your cash fares — with daily, weekly and monthly totals.';

  @override
  String get onbGetStarted => 'Get started';

  @override
  String get onbSmsTitle => 'Allow SMS access';

  @override
  String get onbSmsGrantedTitle => 'SMS access granted';

  @override
  String get onbSmsBody =>
      'Taxi Pay reads the payment confirmations teleBirr sends from short code 127. No other messages are ever read or stored.';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbRestrictedTitle => 'Android blocked the request';

  @override
  String get onbRestrictedBody =>
      'For apps installed outside the Play Store, Android hides the permission dialog until you allow it once. Do this:';

  @override
  String get onbStep1 =>
      'Open Settings below (or long-press the Taxi Pay icon → App info)';

  @override
  String get onbStep2 => 'Tap the ⋮ menu at the top right';

  @override
  String get onbStep3 => 'Tap \"Allow restricted settings\"';

  @override
  String get onbStep4 => 'Come back and press \"Check again\"';

  @override
  String get onbOpenSettings => 'Open Settings';

  @override
  String get onbCheckAgain => 'Check again';

  @override
  String get onbBatteryTitle => 'Stay awake in the background';

  @override
  String get onbBatteryOkTitle => 'Battery optimization off';

  @override
  String get onbBatteryBody =>
      'To save battery, Android can pause apps in the background — that would delay payment capture while your screen is off. Exempting Taxi Pay keeps the listener alive during a shift.';

  @override
  String get onbAllowBackground => 'Allow in background';

  @override
  String get onbAllSet => 'You\'re all set';

  @override
  String get onbSkip => 'Skip for now';

  @override
  String get onbFinish => 'Finish';
}
