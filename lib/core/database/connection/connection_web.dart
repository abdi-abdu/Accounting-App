import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web connection — Drift over WebAssembly SQLite, persisted via OPFS.
///
/// Per the confirmed Module 5 platform decision: web offline storage has
/// NO SQLCipher-equivalent at-rest encryption. Data relies on standard
/// browser storage sandboxing, not a true encrypted file. This is an
/// accepted, documented limitation — not an oversight — pending the
/// mobile app's full SQLCipher encryption.
///
/// IMPORTANT: the exact asset/worker setup this requires (sqlite3.wasm,
/// the Drift worker script, and COOP/COEP headers for the fast OPFS path)
/// changes across Drift versions. Verify against Drift's current official
/// "Using Drift on the web" documentation before relying on this in
/// production — do not assume this snippet alone is sufficient without
/// also completing the web/ folder asset setup described there.
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final db = await WasmDatabase.open(
      databaseName: 'sba_app',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    if (db.missingFeatures.isNotEmpty) {
      // Some browsers (notably older Safari) may fall back to a less
      // durable storage mode. Surface this via syncStatusProvider once
      // that's built (Phase 6) rather than failing silently.
      // ignore: avoid_print
      print('Drift web storage running in degraded mode: ${db.missingFeatures}');
    }

    return db.resolvedExecutor;
  }));
}
