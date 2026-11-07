// TEMPORARY — smoke-test only. Remove once the first real feature uses the DB.
// Verifies the local Drift database opens and accepts writes on web.
// Shown as a single status line on PlaceholderHomeScreen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'app_database_provider.dart';

/// Inserts one row into the placeholder SchemaVersionMeta table and returns
/// the total row count. Proves the WASM/OPFS (web) or SQLCipher (mobile)
/// connection opened correctly and that read/write round-trips work.
///
/// TEMPORARY — remove along with PlaceholderHomeScreen when Phase 5 begins.
final localDbCheckProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);

  // Insert a test row (version = 1 is fine; this table exists only for
  // Phase 0 proof-of-life and has no uniqueness constraints).
  await db.into(db.schemaVersionMeta).insert(
        SchemaVersionMetaCompanion.insert(version: 1),
      );

  // Return total row count — visible on screen so we can confirm persistence
  // across hot-restarts.
  final rows = await db.select(db.schemaVersionMeta).get();
  return rows.length;
});
