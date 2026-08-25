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
}
