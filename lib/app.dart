import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/locale_provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class SbaApp extends ConsumerWidget {
  const SbaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeControllerProvider).valueOrNull ?? const Locale('en');

    // Flutter's built-in Material/Widgets/Cupertino translations don't
    // cover every locale we support (e.g. Afaan Oromo). For the framework
    // "chrome" (default tooltips etc.), we fall back to English when that
    // happens. Our OWN app text is unaffected — it comes from
    // appL10nProvider (core/localization/app_l10n_provider.dart), which
    // fetches translations directly and doesn't depend on Flutter's
    // locale-support list at all.
    final materialSupportsLocale = GlobalMaterialLocalizations.delegate.isSupported(locale);
    final frameworkLocale = materialSupportsLocale ? locale : const Locale('en');

    return MaterialApp.router(
      title: 'SBA App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: frameworkLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}