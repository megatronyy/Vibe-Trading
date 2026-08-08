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

  runApp(UncontrolledProviderScope(
    container: container,
    child: const App(),
  ));
}
