/// Wraps [flutter_secure_storage] for secrets and the small set of
/// non-secret app preferences that the React frontend kept in `localStorage`.
///
/// Keys kept here (never logged/redacted on read):
/// - [apiKeyKey]   — `API_AUTH_KEY` (Bearer token for non-loopback backends)
/// - [baseUrlKey]  — self-hosted backend base URL
/// - [themeKey]    — persisted theme mode (light/dark/system)
/// - [localeKey]   — persisted language code
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

  Future<String?> getApiKey() => _storage.read(key: apiKeyKey);
  Future<void> setApiKey(String? value) => _writeOrDelete(apiKeyKey, value);

  Future<String?> getBaseUrl() => _storage.read(key: baseUrlKey);
  Future<void> setBaseUrl(String? value) => _writeOrDelete(baseUrlKey, value);

  Future<String?> getThemeMode() => _storage.read(key: themeKey);
  Future<void> setThemeMode(String? value) => _writeOrDelete(themeKey, value);

  Future<String?> getLocale() => _storage.read(key: localeKey);
  Future<void> setLocale(String? value) => _writeOrDelete(localeKey, value);

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
