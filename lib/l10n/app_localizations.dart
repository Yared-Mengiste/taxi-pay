import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
  ];

  /// No description provided for @navSession.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get navSession;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @homeStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get homeStart;

  /// No description provided for @homeIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Ready to work? Start a session to track teleBirr payments.'**
  String get homeIdleHint;

  /// No description provided for @shiftFinished.
  ///
  /// In en, this message translates to:
  /// **'Shift finished'**
  String get shiftFinished;

  /// No description provided for @paymentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} payment} other{{count} payments}}'**
  String paymentsCount(num count);

  /// No description provided for @liveSince.
  ///
  /// In en, this message translates to:
  /// **'LIVE · since {time}'**
  String liveSince(Object time);

  /// No description provided for @paymentsThisSession.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} payment this session} other{{count} payments this session}}'**
  String paymentsThisSession(num count);

  /// No description provided for @actionCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get actionCash;

  /// No description provided for @actionStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get actionStop;

  /// No description provided for @cashFare.
  ///
  /// In en, this message translates to:
  /// **'Cash fare'**
  String get cashFare;

  /// No description provided for @telebirrPayment.
  ///
  /// In en, this message translates to:
  /// **'teleBirr payment'**
  String get telebirrPayment;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet: {amount}'**
  String walletBalance(Object amount);

  /// No description provided for @syncTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync missed SMS'**
  String get syncTooltip;

  /// No description provided for @syncRecovered.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced {count} missed payment from your inbox.} other{Synced {count} missed payments from your inbox.}}'**
  String syncRecovered(num count);

  /// No description provided for @syncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'All payments are up to date.'**
  String get syncUpToDate;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the SMS inbox — check the SMS permission.'**
  String get syncFailed;

  /// No description provided for @stopConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this session?'**
  String get stopConfirmTitle;

  /// No description provided for @stopConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The shift summary stays on the home screen, and the session moves to the dashboard\'s past sessions.'**
  String get stopConfirmBody;

  /// No description provided for @stopConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Stop session'**
  String get stopConfirmAction;

  /// No description provided for @stopConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get stopConfirmCancel;

  /// No description provided for @simulateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send a test payment'**
  String get simulateTooltip;

  /// No description provided for @simulateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a test payment'**
  String get simulateSheetTitle;

  /// No description provided for @simulateSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Builds a realistic teleBirr SMS and runs it through the real capture pipeline. No money moves — it only tests the app.'**
  String get simulateSheetBody;

  /// No description provided for @simulatePayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Payer name'**
  String get simulatePayerLabel;

  /// No description provided for @simulatePayerHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Abebe Balcha'**
  String get simulatePayerHint;

  /// No description provided for @simulatePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Payer phone'**
  String get simulatePhoneLabel;

  /// No description provided for @simulatePhoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 09** ***234'**
  String get simulatePhoneHint;

  /// No description provided for @simulateSend.
  ///
  /// In en, this message translates to:
  /// **'Send test SMS'**
  String get simulateSend;

  /// No description provided for @simulateDone.
  ///
  /// In en, this message translates to:
  /// **'Test payment captured.'**
  String get simulateDone;

  /// No description provided for @simulateDropped.
  ///
  /// In en, this message translates to:
  /// **'Nothing was captured — is a session running?'**
  String get simulateDropped;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Past sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments in this session.'**
  String get sessionNoPayments;

  /// No description provided for @actionFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get actionFuel;

  /// No description provided for @expenseFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get expenseFuel;

  /// No description provided for @expenseOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseOther;

  /// No description provided for @expenseSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an expense'**
  String get expenseSheetTitle;

  /// No description provided for @expenseSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Fuel and other running costs are subtracted from the session\'s net earnings.'**
  String get expenseSheetBody;

  /// No description provided for @expenseNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get expenseNoteLabel;

  /// No description provided for @expenseNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. full tank'**
  String get expenseNoteHint;

  /// No description provided for @expensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Expenses: {amount}'**
  String expensesLabel(Object amount);

  /// No description provided for @netLabel.
  ///
  /// In en, this message translates to:
  /// **'Net: {amount}'**
  String netLabel(Object amount);

  /// No description provided for @cashSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a cash fare'**
  String get cashSheetTitle;

  /// No description provided for @cashSheetBody.
  ///
  /// In en, this message translates to:
  /// **'Cash fares join the same session total as teleBirr payments.'**
  String get cashSheetBody;

  /// No description provided for @cashAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount in birr'**
  String get cashAmountLabel;

  /// No description provided for @cashAmountHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 150'**
  String get cashAmountHint;

  /// No description provided for @cashAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cashAdd;

  /// No description provided for @editCashTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit cash fare'**
  String get editCashTitle;

  /// No description provided for @editCashBody.
  ///
  /// In en, this message translates to:
  /// **'Correct the amount, or delete this entry if it was a mistake.'**
  String get editCashBody;

  /// No description provided for @editCashSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editCashSave;

  /// No description provided for @editCashDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get editCashDelete;

  /// No description provided for @editCashDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get editCashDeleteConfirmTitle;

  /// No description provided for @editCashDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the session total. This can\'t be undone.'**
  String get editCashDeleteConfirmBody;

  /// No description provided for @editCashDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editCashDeleteConfirmAction;

  /// No description provided for @editCashDeleteConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editCashDeleteConfirmCancel;

  /// No description provided for @feedWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for teleBirr payments…'**
  String get feedWaitingTitle;

  /// No description provided for @feedWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Payments sent to your phone appear here instantly.\nPassengers paying cash? Log it below.'**
  String get feedWaitingBody;

  /// No description provided for @feedAddCash.
  ///
  /// In en, this message translates to:
  /// **'Add cash fare'**
  String get feedAddCash;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageAmharic.
  ///
  /// In en, this message translates to:
  /// **'አማርኛ'**
  String get languageAmharic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get settingsPermissionsTitle;

  /// No description provided for @settingsDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataTitle;

  /// No description provided for @settingsPermissionSms.
  ///
  /// In en, this message translates to:
  /// **'SMS access (teleBirr 127)'**
  String get settingsPermissionSms;

  /// No description provided for @settingsPermissionSmsDenied.
  ///
  /// In en, this message translates to:
  /// **'Needed to capture payments'**
  String get settingsPermissionSmsDenied;

  /// No description provided for @settingsPermissionBattery.
  ///
  /// In en, this message translates to:
  /// **'Exempt from battery optimization'**
  String get settingsPermissionBattery;

  /// No description provided for @settingsPermissionBatteryDenied.
  ///
  /// In en, this message translates to:
  /// **'Needed for background capture'**
  String get settingsPermissionBatteryDenied;

  /// No description provided for @settingsGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get settingsGranted;

  /// No description provided for @settingsDenied.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get settingsDenied;

  /// No description provided for @settingsOpenAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get settingsOpenAppSettings;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone. Only teleBirr confirmations from 127 are read — no account, no upload.'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Taxi Pay v1.0.0'**
  String get settingsVersion;

  /// No description provided for @backupAction.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get backupAction;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a copy of all your data as one file'**
  String get backupSubtitle;

  /// No description provided for @backupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup ready — choose where to keep it.'**
  String get backupDone;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed. Try again.'**
  String get backupFailed;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @periodDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get periodDaily;

  /// No description provided for @periodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get periodWeekly;

  /// No description provided for @periodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get periodMonthly;

  /// No description provided for @window7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get window7Days;

  /// No description provided for @window8Weeks.
  ///
  /// In en, this message translates to:
  /// **'Last 8 weeks'**
  String get window8Weeks;

  /// No description provided for @window12Months.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get window12Months;

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get perDay;

  /// No description provided for @perWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get perWeek;

  /// No description provided for @perMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get perMonth;

  /// No description provided for @avgPerPeriod.
  ///
  /// In en, this message translates to:
  /// **'{amount} avg / {period}'**
  String avgPerPeriod(Object amount, Object period);

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No revenue in this period yet'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start a session and take payments — daily, weekly and\nmonthly totals will show up here as bar charts.'**
  String get dashboardEmptyBody;

  /// No description provided for @exportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportTooltip;

  /// No description provided for @exportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments in this period to export.'**
  String get exportEmpty;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Exported {count} payment as CSV.} other{Exported {count} payments as CSV.}}'**
  String exportDone(num count);

  /// No description provided for @exportRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Export which period?'**
  String get exportRangeTitle;

  /// No description provided for @exportRangeThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get exportRangeThisWeek;

  /// No description provided for @exportRangeLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get exportRangeLastWeek;

  /// No description provided for @exportRangeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get exportRangeThisMonth;

  /// No description provided for @exportRangeLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get exportRangeLastMonth;

  /// No description provided for @exportRangeLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get exportRangeLast7Days;

  /// No description provided for @exportRangeLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get exportRangeLast30Days;

  /// No description provided for @exportRangeAllTime.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get exportRangeAllTime;

  /// No description provided for @exportRangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom range…'**
  String get exportRangeCustom;

  /// No description provided for @exportPickStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get exportPickStartDate;

  /// No description provided for @exportPickEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get exportPickEndDate;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Taxi Pay'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Track the teleBirr payments passengers send you during a shift, plus your cash fares — with daily, weekly and monthly totals.'**
  String get onbWelcomeBody;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onbGetStarted;

  /// No description provided for @onbSmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow SMS access'**
  String get onbSmsTitle;

  /// No description provided for @onbSmsGrantedTitle.
  ///
  /// In en, this message translates to:
  /// **'SMS access granted'**
  String get onbSmsGrantedTitle;

  /// No description provided for @onbSmsBody.
  ///
  /// In en, this message translates to:
  /// **'Taxi Pay reads the payment confirmations teleBirr sends from short code 127. No other messages are ever read or stored.'**
  String get onbSmsBody;

  /// No description provided for @onbContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onbContinue;

  /// No description provided for @onbRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Android blocked the request'**
  String get onbRestrictedTitle;

  /// No description provided for @onbRestrictedBody.
  ///
  /// In en, this message translates to:
  /// **'For apps installed outside the Play Store, Android hides the permission dialog until you allow it once. Do this:'**
  String get onbRestrictedBody;

  /// No description provided for @onbStep1.
  ///
  /// In en, this message translates to:
  /// **'Open Settings below (or long-press the Taxi Pay icon → App info)'**
  String get onbStep1;

  /// No description provided for @onbStep2.
  ///
  /// In en, this message translates to:
  /// **'Tap the ⋮ menu at the top right'**
  String get onbStep2;

  /// No description provided for @onbStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Allow restricted settings\"'**
  String get onbStep3;

  /// No description provided for @onbStep4.
  ///
  /// In en, this message translates to:
  /// **'Come back and press \"Check again\"'**
  String get onbStep4;

  /// No description provided for @onbOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get onbOpenSettings;

  /// No description provided for @onbCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get onbCheckAgain;

  /// No description provided for @onbBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Stay awake in the background'**
  String get onbBatteryTitle;

  /// No description provided for @onbBatteryOkTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery optimization off'**
  String get onbBatteryOkTitle;

  /// No description provided for @onbBatteryBody.
  ///
  /// In en, this message translates to:
  /// **'To save battery, Android can pause apps in the background — that would delay payment capture while your screen is off. Exempting Taxi Pay keeps the listener alive during a shift.'**
  String get onbBatteryBody;

  /// No description provided for @onbAllowBackground.
  ///
  /// In en, this message translates to:
  /// **'Allow in background'**
  String get onbAllowBackground;

  /// No description provided for @onbAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get onbAllSet;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onbSkip;

  /// No description provided for @onbFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get onbFinish;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
