import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/session_state.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../../core/database/local_db_check_provider.dart';
import '../../../../core/localization/app_l10n_provider.dart';
import '../../../../core/localization/locale_provider.dart';

/// Phase 0 proof-of-life screen. Confirms:
/// - Supabase auth session resolved
/// - `profiles` row fetched successfully (role + business_id readable under RLS)
/// - Local database opened without error (encrypted on mobile, WASM/OPFS on web)
/// - Localization is wired end-to-end across English, Amharic, and Afan Oromo
/// This screen is replaced entirely once real dashboard work (Phase 5) begins.
class PlaceholderHomeScreen extends ConsumerWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appL10nProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final currentLocale = ref.watch(localeControllerProvider).valueOrNull;
    // Touching the provider confirms the local DB opens without throwing.
    ref.watch(appDatabaseProvider);
    // TEMPORARY — smoke-test; remove with this screen when Phase 5 begins.
    final dbCheckAsync = ref.watch(localDbCheckProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setupVerifiedTitle),
        actions: [
          IconButton(
            tooltip: l10n.signOutTooltip,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            profileAsync.when(
              data: (profile) => profile == null
                  ? Text(l10n.noProfileFound)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 48),
                        const SizedBox(height: 12),
                        Text(l10n.signedInAs(profile.fullName)),
                        Text(l10n.roleLabel(profile.role.name)),
                        Text(l10n.businessIdLabel(profile.businessId ?? '(none)')),
                      ],
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text(l10n.errorLoadingProfile(err.toString())),
            ),
            const SizedBox(height: 32),
            Text(l10n.languageLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<Locale>(
              segments: [
                ButtonSegment(value: const Locale('en'), label: Text(l10n.languageEnglish)),
                ButtonSegment(value: const Locale('am'), label: Text(l10n.languageAmharic)),
                ButtonSegment(value: const Locale('om'), label: Text(l10n.languageOromo)),
              ],
              selected: {currentLocale ?? const Locale('en')},
              onSelectionChanged: (selection) {
                ref.read(localeControllerProvider.notifier).setLocale(selection.first);
              },
            ),
            // TEMPORARY — local DB smoke-test line; remove with this screen when Phase 5 begins.
            const SizedBox(height: 24),
            dbCheckAsync.when(
              data: (count) => Text(
                'Local DB OK, rows: $count',
                style: TextStyle(color: Colors.green[700], fontSize: 12),
              ),
              loading: () => const Text('Local DB: checking…', style: TextStyle(fontSize: 12)),
              error: (err, _) => Text(
                'Local DB error: $err',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}