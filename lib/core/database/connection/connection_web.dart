import 'package:flutter/foundation.dart';
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
/// Assets required in web/:
///   sqlite3.wasm        — from github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-2.9.4
///   drift_worker.dart.js — from github.com/simolus3/drift/releases/tag/drift-2.31.0
///                          (released as drift_worker.js; renamed to match driftWorkerUri below)
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'sba_app',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    // Log the chosen storage implementation so it's visible in the browser
    // console during development. opfsShared/opfsLocks = durable OPFS storage;
    // sharedIndexedDb/unsafeIndexedDb = IndexedDB fallback (less durable);
    // inMemory = no persistence at all (COOP/COEP headers missing or browser
    // too old).
    debugPrint('[Drift] storage implementation: ${result.chosenImplementation}');

    if (result.missingFeatures.isNotEmpty) {
      // Some browsers (notably older Safari) may fall back to a less
      // durable storage mode. Surface this via syncStatusProvider once
      // that's built (Phase 6) rather than failing silently.
      debugPrint('[Drift] missing browser features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  }));
}
