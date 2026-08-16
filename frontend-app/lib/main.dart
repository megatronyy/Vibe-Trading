import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/config/app_config.dart';
import 'core/state/auth_provider.dart';

/// Entry point. Primes persisted state (backend connection, auth, theme,
/// language) from secure storage / preferences before the first frame, then
/// boots the Riverpod-scoped [App]. Loading auth here means the router's
/// redirect sees the real auth status on the very first navigation — no flash
/// of /agent before bouncing an unauthenticated user to /login.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await Future.wait([
    container.read(appConfigProvider.notifier).load(),
    container.read(themeModeProvider.notifier).load(),
    container.read(localeProvider.notifier).load(),
    container.read(authProvider.notifier).load(),
  ]);
  // A JWT that expired while the app was closed: try one /auth/refresh. If
  // that also fails we log out cleanly, so the router lands on /login instead
  // of every request 401-ing against a stale "logged in" state.
  await container.read(authProvider.notifier).checkAndRefresh();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const App(),
  ));
}
