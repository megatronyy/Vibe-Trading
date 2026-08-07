import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/secure_store.dart';

/// Supported UI locales — English, Chinese, Japanese, Korean, Arabic (RTL).
/// Matches the React frontend's `SUPPORTED_LANGUAGES`.
const supportedLocales = [
  Locale('en'),
  Locale('zh'),
  Locale('ja'),
  Locale('ko'),
  Locale('ar'),
];

/// Persisted theme mode (system / light / dark). Replaces the React
/// `localStorage("qa-theme")` + `prefers-color-scheme` logic.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> load() async {
    final saved = await secureStore.getThemeMode();
    state = _parse(saved) ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await secureStore.setThemeMode(mode.name);
  }

  ThemeMode? _parse(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Persisted UI language code (en/zh/ja/ko/ar). `null` ⇒ follow the device.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  Future<void> load() async {
    final code = await secureStore.getLocale();
    state = code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    await secureStore.setLocale(locale?.languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
