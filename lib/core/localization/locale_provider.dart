import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per your confirmed decision: language preference is local to each
/// device (not synced via the database). Defaults to English; the user
/// can change it anytime from within the app.
class LocaleController extends AsyncNotifier<Locale> {
  static const _prefsKey = 'preferred_locale';
  static const supportedLocales = [Locale('en'), Locale('am'), Locale('om')];

  @override
  Future<Locale> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    return supportedLocales.firstWhere(
      (l) => l.languageCode == saved,
      orElse: () => const Locale('en'),
    );
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
    state = AsyncData(locale);
  }
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale>(LocaleController.new);
