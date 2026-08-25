import 'package:flutter/material.dart';

/// Minimal placeholder theme for Phase 0.
/// `fontFamilyFallback` ensures Amharic (Ge'ez script) text renders
/// correctly even though the primary font is Latin-oriented — without
/// this, Amharic characters would fall back to a system default that may
/// render as boxes/tofu on some devices. Requires NotoSansEthiopic to be
/// added as a bundled asset (see pubspec.yaml `fonts:` section and
/// SETUP_GUIDE.md — the font file itself must be downloaded separately,
/// it could not be fetched in the sandbox this scaffold was built in).
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        appBarTheme: const AppBarTheme(centerTitle: true),
        fontFamilyFallback: const ['NotoSansEthiopic'],
      );
}
