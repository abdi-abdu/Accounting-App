import 'package:drift/drift.dart';

import 'connection/connection_native.dart'
    if (dart.library.js_interop) 'connection/connection_web.dart' as impl;

part 'app_database.g.dart';

/// Placeholder table so Drift's code generator has something to build
/// against in Phase 0. Real Module 4 tables (categories, items,
/// stock_batches, sales, sale_items, expenses, etc.) are added one feature
/// at a time starting in Phase 2 — intentionally not created yet, per
/// the "no business modules" instruction for this session.
class SchemaVersionMeta extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get version => integer()();
}

/// Platform-conditional local database (Module 5, §1a):
/// - Web: Drift over WASM SQLite + OPFS, no at-rest encryption (accepted limitation)
/// - Mobile (later): Drift over native SQLite via SQLCipher, fully encrypted
@DriftDatabase(tables: [SchemaVersionMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.openConnection());

  @override
  int get schemaVersion => 1;
}
