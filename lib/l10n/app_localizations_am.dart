// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get navSession => 'የስራ ጊዜ';

  @override
  String get navDashboard => 'ሪፖርት';

  @override
  String get navSettings => 'ቅንብሮች';

  @override
  String get homeStart => 'ጀምር';

  @override
  String get homeIdleHint => 'ለስራ ዝግጁ? የተሌቢር ክፍያዎችን ለመከታተል ክፍለ ጊዜ ይጀምሩ።';

  @override
  String get shiftFinished => 'ስራው አለቀ';

  @override
  String get recentRoutes => 'የቅርብ ጊዜ መንገዶች';

  @override
  String paymentsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክፍያ',
    );
    return '$_temp0';
  }

  @override
  String liveSince(Object time) {
    return 'በሂደት ላይ · ከ$time ጀምሮ';
  }

  @override
  String paymentsThisSession(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በዚህ ክፍለ ጊዜ $count ክፍያ',
    );
    return '$_temp0';
  }

  @override
  String get actionCash => 'ጥሬ ገንዘብ';

  @override
  String get actionStop => 'አቁም';

  @override
  String get cashFare => 'የጥሬ ገንዘብ ክፍያ';

  @override
  String get telebirrPayment => 'የተሌቢር ክፍያ';

  @override
  String walletBalance(Object amount) {
    return 'ቀሪ ሂሳብ፦ $amount';
  }

  @override
  String get syncTooltip => 'ያመለጡ ኤስኤምኤስ አሳምር';

  @override
  String syncRecovered(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ያልተመዘገቡ ክፍያዎች ተጨምረዋል።',
    );
    return '$_temp0';
  }

  @override
  String get syncUpToDate => 'ሁሉም ክፍያዎች አሁንም ተመዝግበዋል።';

  @override
  String get syncFailed => 'የኤስኤምኤስ ገቢ ሳጥንን ማንበብ አልተቻለም — የኤስኤምኤስ ፈቃዱን ይፈትሹ።';

  @override
  String get stopConfirmTitle => 'ይህ ክፍለ ጊዜ ይቁም?';

  @override
  String get stopConfirmBody =>
      'የስራው ማጠቃለያ በመነሻ ገጹ ላይ ይቆያል፤ ክፍለ ጊዜውም ወደ ሪፖርቱ ያሉት ክፍለ ጊዜዎች ይሰጋል።';

  @override
  String get stopConfirmAction => 'አቁም';

  @override
  String get stopConfirmCancel => 'ቀጥል';

  @override
  String get simulateTooltip => 'የሙከራ ክፍያ ላክ';

  @override
  String get simulateSheetTitle => 'የሙከራ ክፍያ ላክ';

  @override
  String get simulateSheetBody =>
      'እውነተኛ የተሌቢር መልእክት መስሎ በትክክለኛው የመቀበያ ሂደት ይራራል። ገንዘብ አይንቀሳቀስም — መተግበሪያውን ለመፈተሽ ብቻ ነው።';

  @override
  String get simulatePayerLabel => 'የከፋይ ስም';

  @override
  String get simulatePayerHint => 'ለምሳሌ አበበ በላች';

  @override
  String get simulatePhoneLabel => 'የከፋይ ስልክ';

  @override
  String get simulatePhoneHint => 'ለምሳሌ 0911***234';

  @override
  String get simulateSend => 'የሙከራ መልእክት ላክ';

  @override
  String get simulateDone => 'የሙከራ ክፍያ ተመዝግቧል።';

  @override
  String get simulateDropped => 'ነገር አልተመዘገበም — ክፍለ ጊዜ ተጀምሯል?';

  @override
  String get sessionsTitle => 'ያለፉ ክፍለ ጊዜዎች';

  @override
  String get sessionNoPayments => 'በዚህ ክፍለ ጊዜ ክፍያ አልተመዘገበም።';

  @override
  String get actionFuel => 'ነዳጅ';

  @override
  String get expenseFuel => 'ነዳጅ';

  @override
  String get expenseOther => 'ሌላ';

  @override
  String get expenseSheetTitle => 'ወጪ ያስገቡ';

  @override
  String get expenseSheetBody => 'የነዳጅ እና ሌሎች ወጪዎች ከስራው ትርፍ ይቀነሳሉ።';

  @override
  String get expenseNoteLabel => 'ማስታወሻ (አማራጭ)';

  @override
  String get expenseNoteHint => 'ለምሳሌ ሙሉ ማጠራረብ';

  @override
  String expensesLabel(Object amount) {
    return 'ወጪ፦ $amount';
  }

  @override
  String netLabel(Object amount) {
    return 'ትርፍ፦ $amount';
  }

  @override
  String get cashSheetTitle => 'የጥሬ ገንዘብ ክፍያ ያስገቡ';

  @override
  String get cashSheetBody => 'የጥሬ ገንዘብ ክፍያዎች ከተሌቢር ክፍያዎች ጋር በተመሳሳይ ድምር ይታሰባሉ።';

  @override
  String get cashAmountLabel => 'መጠን በብር';

  @override
  String get cashAmountHint => 'ለምሳሌ 150';

  @override
  String get cashAdd => 'ጨምር';

  @override
  String get editCashTitle => 'የጥሬ ገንዘብ ክፍያን አስተካክል';

  @override
  String get editCashBody => 'መጠኑን ያስተካክሉ፣ ወይም ስህተት ከሆነ ክፍያውን ይሰርዙ።';

  @override
  String get editCashSave => 'አስቀምጥ';

  @override
  String get editCashDelete => 'ክፍያውን ሰርዝ';

  @override
  String get editCashDeleteConfirmTitle => 'ይህ ክፍያ ይሰረዝ?';

  @override
  String get editCashDeleteConfirmBody => 'ከድምሩ ይጠፋል። ከሰረዙ በኋላ መመለስ አይቻልም።';

  @override
  String get editCashDeleteConfirmAction => 'ሰርዝ';

  @override
  String get editCashDeleteConfirmCancel => 'ተወው';

  @override
  String get feedWaitingTitle => 'የተሌቢር ክፍያዎችን በመጠበቅ ላይ…';

  @override
  String get feedWaitingBody =>
      'ወደ ስልክዎ የተላኩ ክፍያዎች ወዲያውኑ እዚህ ይታያሉ።\nበጥሬ ገንዘብ የሚከፈል ከሆነ? ከታች ያስገቡ።';

  @override
  String get feedAddCash => 'የጥሬ ገንዘብ ክፍያ ያስገቡ';

  @override
  String get languageTitle => 'ቋንቋ';

  @override
  String get languageSystem => 'የስርዓቱ ነባሪ';

  @override
  String get languageAmharic => 'አማርኛ';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTitle => 'ቅንብሮች';

  @override
  String get themeTitle => 'ገጽታ';

  @override
  String get themeSystem => 'የስርዓቱን ይከተሉ';

  @override
  String get themeLight => 'ብርሃናማ';

  @override
  String get themeDark => 'ጨለማ';

  @override
  String get settingsPermissionsTitle => 'ፈቃዶች';

  @override
  String get settingsDataTitle => 'መረጃ';

  @override
  String get settingsPermissionSms => 'የኤስኤምኤስ ፈቃድ (ተሌቢር 127)';

  @override
  String get settingsPermissionSmsDenied => 'ክፍያዎችን ለመቅረጽ ያስፈልጋል';

  @override
  String get settingsPermissionBattery => 'ከባትሪ ቆጣቢ የተነጠቀ';

  @override
  String get settingsPermissionBatteryDenied => 'በጀርባ ላይ ለመቅረጽ ያስፈልጋል';

  @override
  String get settingsGranted => 'ተፈቅዷል';

  @override
  String get settingsDenied => 'አልተፈቀደም';

  @override
  String get settingsOpenAppSettings => 'የመተግበሪያ ቅንብሮችን ክፈት';

  @override
  String get settingsPrivacyTitle => 'ግላዊ በንድፈ ሃሳብ';

  @override
  String get settingsPrivacyBody =>
      'ሁሉም መረጃ በዚህ ስልክ ላይ ይቀመጣል። ከ127 የሚላኩ የተሌቢር ማረገጫዎች ብቻ ይነበባሉ — መለያ የለም፣ መላክ የለም።';

  @override
  String get settingsVersion => 'ታክሲ ፔይ ስሪት 1.0.0';

  @override
  String get backupAction => 'መጠባበቂያ ላክ';

  @override
  String get backupSubtitle => 'ሙሉ መረጃዎን በአንድ ፋይል ያጋሩ';

  @override
  String get backupDone => 'መጠባበቂያ ተዘጋጅል — የሚቀመጥበት ቦታ ይምረጡ።';

  @override
  String get backupFailed => 'መጠባበቂያ አልተሳካም። እንደገና ይሞክሩ።';

  @override
  String get dashboardTitle => 'ሪፖርት';

  @override
  String get periodDaily => 'ዕለታዊ';

  @override
  String get periodWeekly => 'ሳምንታዊ';

  @override
  String get periodMonthly => 'ወርሃዊ';

  @override
  String get window7Days => 'ያለፉት 7 ቀናት';

  @override
  String get window8Weeks => 'ያለፉት 8 ሳምንታት';

  @override
  String get window12Months => 'ያለፉት 12 ወራት';

  @override
  String get perDay => 'ቀን';

  @override
  String get perWeek => 'ሳምንት';

  @override
  String get perMonth => 'ወር';

  @override
  String avgPerPeriod(Object amount, Object period) {
    return 'በአማካይ $amount / $period';
  }

  @override
  String get dashboardEmptyTitle => 'በዚህ ጊዜ ገቢ አልተመዘገበም';

  @override
  String get dashboardEmptyBody =>
      'ክፍለ ጊዜ ይጀምሩና ክፍያዎችን ይቀበሉ — ዕለታዊ፣ ሳምንታዊ እና\nወርሃዊ ድምሮች እዚህ በግራፍ ይታያሉ።';

  @override
  String get exportTooltip => 'CSV ላክ';

  @override
  String get exportEmpty => 'በዚህ ጊዜ ለማንሳት ክፍያ የለም።';

  @override
  String exportDone(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክፍያዎችን በCSV ላከ።',
    );
    return '$_temp0';
  }

  @override
  String get exportRangeTitle => 'የትኛውን ጊዜ ይላኩ?';

  @override
  String get exportRangeThisWeek => 'ይህ ሳምንት';

  @override
  String get exportRangeLastWeek => 'ያለፈው ሳምንት';

  @override
  String get exportRangeThisMonth => 'ይህ ወር';

  @override
  String get exportRangeLastMonth => 'ያለፈው ወር';

  @override
  String get exportRangeLast7Days => 'ያለፉት 7 ቀናት';

  @override
  String get exportRangeLast30Days => 'ያለፉት 30 ቀናት';

  @override
  String get exportRangeAllTime => 'ሁሉም';

  @override
  String get exportRangeCustom => 'በራስ የተመረጠ ጊዜ…';

  @override
  String get exportPickStartDate => 'የመጀመሪያ ቀን';

  @override
  String get exportPickEndDate => 'የመጨረሻ ቀን';

  @override
  String get onbWelcomeTitle => 'እንኳን ወደ ታክሲ ፔይ በደህና መጡ';

  @override
  String get onbWelcomeBody =>
      'በስራ ጊዜ የተላኩትን የተሌቢር ክፍያዎች እና የጥሬ ገንዘብ ክፍያዎችዎን በአንድነት ይከታተሉ — በዕለት፣ በሳምንት እና በወር ድምሮች።';

  @override
  String get onbGetStarted => 'ጀምር';

  @override
  String get onbSmsTitle => 'የኤስኤምኤስ ፈቃድ ይፍቁ';

  @override
  String get onbSmsGrantedTitle => 'የኤስኤምኤስ ፈቃድ ተሰጠ';

  @override
  String get onbSmsBody =>
      'ታክሲ ፔይ ከ127 ቁጥር የሚላኩትን የተሌቢር የክፍያ ማረገጫዎች ብቻ ያነባል። ሌላ መልእክት በጭራሽ አይነበብም አይቀመጥም።';

  @override
  String get onbContinue => 'ቀጥል';

  @override
  String get onbRestrictedTitle => 'አንድሮይድ ጥያቄውን ከለከለ';

  @override
  String get onbRestrictedBody =>
      'ከፕሌይ ስቶር ውጭ ከተተከሉ መተግበሪያዎች ፈቃዱ እርስዎ እስክወስኑት ድረስ ተደብቋል። ይህን ያድርጉ:';

  @override
  String get onbStep1 =>
      'ከታች ቅንብሮችን ይክፈቱ (ወይም የታክሲ ፔይ ምልክትን በረጅም ተጭነው → የመተግበሪያ መረጃ)';

  @override
  String get onbStep2 => 'በላይ በቀኝ ባለው ⋮ ምናሌ ይንኩ';

  @override
  String get onbStep3 => '\"የተገደቡ ቅንብሮችን ፍቁ\" የሚለውን ይንኩ';

  @override
  String get onbStep4 => 'ወደነበሩበት ተመልሰው \"እንደገና ይፈትሹ\" የሚለውን ይንኩ';

  @override
  String get onbOpenSettings => 'ቅንብሮችን ክፈት';

  @override
  String get onbCheckAgain => 'እንደገና ይፈትሹ';

  @override
  String get onbBatteryTitle => 'በጀርባ ላይ ንቁ ይሁኑ';

  @override
  String get onbBatteryOkTitle => 'የባትሪ ቆጣቢ ጠፍቷል';

  @override
  String get onbBatteryBody =>
      'ባትሪ ለመቆጠብ አንድሮይድ በጀርባ ያሉ መተግበሪያዎችን ሊያገዳ ይችላል — ስክሪኑ ሲጠፋ ክፍያዎች እንዳይመዘገቡ ሊያዘጋጅ ይችላል። ታክሲ ፔይን መፍቀድ በስራ ጊዜ አዳማጹን ንቃት ላይ ይይዛል።';

  @override
  String get onbAllowBackground => 'በጀርባ ላይ ፍቀድ';

  @override
  String get onbAllSet => 'ሁሉም ዝግጁ ነው';

  @override
  String get onbSkip => 'አሁን ይተዉ';

  @override
  String get onbFinish => 'ጨርስ';
}
