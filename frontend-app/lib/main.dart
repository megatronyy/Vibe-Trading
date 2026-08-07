import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'core/config/app_config.dart';

/// Entry point. Primes persisted state (backend connection, theme, language)
/// from secure storage / preferences before the first frame, then boots the
/// Riverpod-scoped [App].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await Future.wait([
    container.read(appConfigProvider.notifier).load(),
    container.read(themeModeProvider.notifier).load(),
    container.read(localeProvider.notifier).load(),
  ]);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const App(),
  ));
}
