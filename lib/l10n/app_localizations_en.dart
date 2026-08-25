// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SBA App';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get setupVerifiedTitle => 'Setup verified';

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String roleLabel(String role) {
    return 'Role: $role';
  }

  @override
  String businessIdLabel(String id) {
    return 'Business ID: $id';
  }

  @override
  String get noProfileFound => 'No profile found for this user.';

  @override
  String errorLoadingProfile(String error) {
    return 'Error loading profile: $error';
  }

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageAmharic => 'አማርኛ';

  @override
  String get languageOromo => 'Afaan Oromoo';
}
