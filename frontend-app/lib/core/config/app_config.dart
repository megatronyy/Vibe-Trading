import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_store.dart';

/// Backend connection state. Both fields come from [SecureStore] (Keychain /
/// Keystore), replacing the React frontend's `localStorage`.
class AppConfig {
  const AppConfig({this.baseUrl = '', this.apiKey = ''});

  /// Defaults applied when nothing is stored yet, so the app is usable
  /// out-of-the-box against the local backend.
  static const String defaultBaseUrl = 'http://192.168.3.188:8899';
  static const String defaultApiKey = '123456';

  final String baseUrl;
  final String apiKey;

  bool get isConfigured => baseUrl.isNotEmpty;

  AppConfig copyWith({String? baseUrl, String? apiKey}) => AppConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
      );

  static const empty = AppConfig();
}

/// Owns the backend connection config: loads from secure storage at startup
/// (primed in `main`) and persists every change. Other providers ([dioProvider])
/// watch this so a Settings change re-creates the HTTP client live.
class AppConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() =>
      AppConfig(baseUrl: AppConfig.defaultBaseUrl, apiKey: AppConfig.defaultApiKey);

  /// Read persisted values into state. Called once from `main` before the UI
  /// boots so the first frame has the right base URL / key. Falls back to the
  /// built-in defaults when nothing is stored.
  Future<void> load() async {
    final base = await secureStore.getBaseUrl();
    final key = await secureStore.getApiKey();
    state = AppConfig(
      baseUrl: base ?? AppConfig.defaultBaseUrl,
      apiKey: key ?? AppConfig.defaultApiKey,
    );
  }

  Future<void> setBaseUrl(String url) async {
    final normalized = _normalize(url);
    await secureStore.setBaseUrl(normalized.isEmpty ? null : normalized);
    state = state.copyWith(baseUrl: normalized);
  }

  Future<void> setApiKey(String key) async {
    await secureStore.setApiKey(key.isEmpty ? null : key);
    state = state.copyWith(apiKey: key);
  }

  Future<void> clear() async {
    await secureStore.clearAll();
    // Restore the built-in defaults so the app stays usable.
    state = AppConfig(baseUrl: AppConfig.defaultBaseUrl, apiKey: AppConfig.defaultApiKey);
  }

  static String _normalize(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }
}

final appConfigProvider =
    NotifierProvider<AppConfigNotifier, AppConfig>(AppConfigNotifier.new);
