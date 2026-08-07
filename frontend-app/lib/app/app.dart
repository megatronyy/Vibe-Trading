import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import 'app_state.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget. Theme mode, locale, and router are all Riverpod-driven so
/// Settings changes apply live (no reload — unlike the React app).
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      // Explicit user-chosen locale always wins; otherwise resolve the device
      // locale by language code, falling back to the first supported locale.
      localeListResolutionCallback: (deviceLocales, supported) {
        if (locale != null) return locale;
        if (deviceLocales != null) {
          for (final dl in deviceLocales) {
            for (final sl in supported) {
              if (sl.languageCode == dl.languageCode) return sl;
            }
          }
        }
        return supported.first;
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
