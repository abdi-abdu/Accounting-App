import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import '../encryption/db_encryption_service.dart';

/// Mobile (Android/iOS) connection — encrypted via SQLCipher, per the
/// confirmed Module 5 decision. Used only when NOT running on web
/// (see app_database.dart's conditional import).
///
/// NOTE: verify this setup against the current sqlcipher_flutter_libs
/// README before relying on it in production — the exact API has shifted
/// across versions.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sba_app.sqlite'));
    final key = await DbEncryptionService.getOrCreateKey();

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$key';");
      },
    );
  });
}
