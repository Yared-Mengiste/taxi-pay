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
  String get homeStart => 'START';

  @override
  String get homeIdleHint =>
      'Ready to work? Start a session to track teleBirr payments.';

  @override
  String get shiftFinished => 'Shift finished';

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
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

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
