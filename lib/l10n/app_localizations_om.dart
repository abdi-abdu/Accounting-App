// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appTitle => 'Appilikeeshinii SBA';

  @override
  String get signInTitle => 'Seenuu';

  @override
  String get emailLabel => 'Imeelii';

  @override
  String get passwordLabel => 'Jecha Iccitii';

  @override
  String get signInButton => 'Seenuu';

  @override
  String get signOutTooltip => 'Ba\'uu';

  @override
  String get setupVerifiedTitle => 'Qindaa\'inni Mirkanaa\'eera';

  @override
  String signedInAs(String name) {
    return 'Akka $name seentaniirtu';
  }

  @override
  String roleLabel(String role) {
    return 'Gahee: $role';
  }

  @override
  String businessIdLabel(String id) {
    return 'Eenyummaa Daldalaa: $id';
  }

  @override
  String get noProfileFound => 'Fayyadamaa kanaaf ibsi hin argamne.';

  @override
  String errorLoadingProfile(String error) {
    return 'Dogoggora ibsa fe\'uu keessatti: $error';
  }

  @override
  String get languageLabel => 'Afaan';

  @override
  String get languageEnglish => 'Ingiliffa';

  @override
  String get languageAmharic => 'Amaariffa';

  @override
  String get languageOromo => 'Afaan Oromoo';

  @override
  String get signUpTitle => 'Akkaawuntii uumi';

  @override
  String get signUpButton => 'Galmaa\'i';

  @override
  String get alreadyHaveAccount => 'Duraan akkaawuntii qabdaa? Seenuu';

  @override
  String get noAccountYet => 'Akkaawuntii hin qabdu? Galmaa\'i';

  @override
  String get confirmPasswordLabel => 'Jecha iccitii mirkaneessi';

  @override
  String get passwordsDontMatch => 'Jechi iccitii wal hin simne';

  @override
  String get checkEmailTitle => 'Imeelii kee ilaali';

  @override
  String checkEmailBody(String email) {
    return 'Hidhannoo mirkaneessaa gara $email erginee jirra. Tuqi, ergasii deebi\'ii seeni.';
  }

  @override
  String get businessSetupTitle => 'Daldala kee qindeessi';

  @override
  String get businessNameLabel => 'Maqaa Daldalaa';

  @override
  String get fullNameLabel => 'Maqaa kee guutuu';

  @override
  String get completeSetupButton => 'Qindaa\'ina xumuri';

  @override
  String setupFailed(String error) {
    return 'Qindaa\'inni hin milkoofne: $error';
  }
}
