import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates and retrieves the per-device encryption key used to open the
/// local SQLCipher database (Module 5 §10 — confirmed requirement).
///
/// The key itself is generated once per device install and stored in the
/// OS-native secure keychain/keystore — never written alongside the
/// database file, and never hardcoded.
class DbEncryptionService {
  DbEncryptionService._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'sba_app_db_encryption_key';

  static Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return existing;

    final newKey = _generateKey();
    await _storage.write(key: _keyName, value: newKey);
    return newKey;
  }

  static String _generateKey({int length = 32}) {
    final random = Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }
}
