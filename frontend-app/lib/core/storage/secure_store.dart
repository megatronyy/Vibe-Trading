/// Wraps [flutter_secure_storage] for secrets and the small set of
/// non-secret app preferences that the React frontend kept in `localStorage`.
///
/// Keys kept here (never logged/redacted on read):
/// - [apiKeyKey]   — `API_AUTH_KEY` (Bearer token for non-loopback backends)
/// - [baseUrlKey]  — self-hosted backend base URL
/// - [themeKey]    — persisted theme mode (light/dark/system)
/// - [localeKey]   — persisted language code
/// - [jwtKey]      — JWT access token (P1 auth)
/// - [jwtExpKey]   — JWT expiry (ISO-8601)
/// - [userIdKey]   — authenticated user id
/// - [userNameKey] — authenticated display name
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Sentinel for "no value" since secure_storage reads are nullable already,
/// but callers sometimes want to distinguish unset from empty.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String apiKeyKey = 'api_auth_key';
  static const String baseUrlKey = 'base_url';
  static const String themeKey = 'theme_mode';
  static const String localeKey = 'locale';
  static const String jwtKey = 'jwt';
  static const String jwtExpKey = 'jwt_exp';
  static const String userIdKey = 'user_id';
  static const String userNameKey = 'user_name';

  Future<String?> getApiKey() => _storage.read(key: apiKeyKey);
  Future<void> setApiKey(String? value) => _writeOrDelete(apiKeyKey, value);

  Future<String?> getBaseUrl() => _storage.read(key: baseUrlKey);
  Future<void> setBaseUrl(String? value) => _writeOrDelete(baseUrlKey, value);

  Future<String?> getThemeMode() => _storage.read(key: themeKey);
  Future<void> setThemeMode(String? value) => _writeOrDelete(themeKey, value);

  Future<String?> getLocale() => _storage.read(key: localeKey);
  Future<void> setLocale(String? value) => _writeOrDelete(localeKey, value);

  // --- P1 auth: JWT + user identity ---------------------------------------
  Future<String?> getJwt() => _storage.read(key: jwtKey);
  Future<void> setJwt(String? value) => _writeOrDelete(jwtKey, value);

  Future<String?> getJwtExp() => _storage.read(key: jwtExpKey);
  Future<void> setJwtExp(String? value) => _writeOrDelete(jwtExpKey, value);

  Future<String?> getUserId() => _storage.read(key: userIdKey);
  Future<void> setUserId(String? value) => _writeOrDelete(userIdKey, value);

  Future<String?> getUserName() => _storage.read(key: userNameKey);
  Future<void> setUserName(String? value) => _writeOrDelete(userNameKey, value);

  /// Wipe just the auth keys (logout). Connection / theme / locale survive.
  Future<void> clearAuth() async {
    await Future.wait([
      _storage.delete(key: jwtKey),
      _storage.delete(key: jwtExpKey),
      _storage.delete(key: userIdKey),
      _storage.delete(key: userNameKey),
    ]);
  }

  Future<void> _writeOrDelete(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  /// Bulk wipe — used by Settings "clear credentials".
  Future<void> clearAll() => _storage.deleteAll();
}

/// Global instance for non-Riverpod call sites (startup bootstrap).
/// Riverpod callers should use the [secureStoreProvider] instead.
final secureStore = SecureStore();

/// Redact a key for safe logging (first 4 chars + …) — secrets are access,
/// not text; this keeps diagnostics usable without leaking the full token.
String redactKey(String? key) {
  if (key == null || key.isEmpty) return '<none>';
  if (key.length <= 4) return '••••';
  return '${key.substring(0, 4)}…';
}

@visibleForTesting
String sanitizeForLog(String input) => input.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
