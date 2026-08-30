// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'SBA መተግበሪያ';

  @override
  String get signInTitle => 'ግባ';

  @override
  String get emailLabel => 'ኢሜይል';

  @override
  String get passwordLabel => 'የይለፍ ቃል';

  @override
  String get signInButton => 'ግባ';

  @override
  String get signOutTooltip => 'ውጣ';

  @override
  String get setupVerifiedTitle => 'ማዋቀር ተረጋግጧል';

  @override
  String signedInAs(String name) {
    return 'እንደ $name ገብተዋል';
  }

  @override
  String roleLabel(String role) {
    return 'ሚና: $role';
  }

  @override
  String businessIdLabel(String id) {
    return 'የንግድ መታወቂያ: $id';
  }

  @override
  String get noProfileFound => 'ለዚህ ተጠቃሚ መገለጫ አልተገኘም።';

  @override
  String errorLoadingProfile(String error) {
    return 'መገለጫን በመጫን ላይ ስህተት: $error';
  }

  @override
  String get languageLabel => 'ቋንቋ';

  @override
  String get languageEnglish => 'እንግሊዝኛ';

  @override
  String get languageAmharic => 'አማርኛ';

  @override
  String get languageOromo => 'አፋን ኦሮሞ';

  @override
  String get signUpTitle => 'መለያ ይፍጠሩ';

  @override
  String get signUpButton => 'ተመዝገብ';

  @override
  String get alreadyHaveAccount => 'መለያ አለዎት? ይግቡ';

  @override
  String get noAccountYet => 'መለያ የለዎትም? ይመዝገቡ';

  @override
  String get confirmPasswordLabel => 'የይለፍ ቃል ያረጋግጡ';

  @override
  String get passwordsDontMatch => 'የይለፍ ቃላት አይዛመዱም';

  @override
  String get checkEmailTitle => 'ኢሜይልዎን ያረጋግጡ';

  @override
  String checkEmailBody(String email) {
    return 'ወደ $email የማረጋገጫ ማገናኛ ልከናል። ይጫኑት፣ ከዚያም ተመልሰው ይግቡ።';
  }

  @override
  String get businessSetupTitle => 'ንግድዎን ያዋቅሩ';

  @override
  String get businessNameLabel => 'የንግድ ስም';

  @override
  String get fullNameLabel => 'ሙሉ ስምዎ';

  @override
  String get completeSetupButton => 'ማዋቀሩን ጨርስ';

  @override
  String setupFailed(String error) {
    return 'ማዋቀር አልተሳካም: $error';
  }
}
