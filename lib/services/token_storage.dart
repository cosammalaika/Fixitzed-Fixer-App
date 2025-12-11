import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Securely persists the fixer API token, migrating from legacy storage.
class TokenStorage {
  TokenStorage._();

  static const _secureKey = 'fixer_api_token';
  static const _legacyPrefsKey = 'auth_token';

  static final TokenStorage instance = TokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _storage.write(key: _secureKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  Future<String?> getToken() async {
    final existing = await _storage.read(key: _secureKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _secureKey, value: legacy);
      await prefs.remove(_legacyPrefsKey);
      return legacy;
    }

    return null;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _secureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }
}
