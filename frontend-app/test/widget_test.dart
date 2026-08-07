// P0 smoke tests for pure logic that needs no platform channels (secure
// storage / network aren't available in a plain widget test). The full
// Agent/SSE/Settings flows get integration tests once a backend fixture
// exists.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/app/theme.dart';
import 'package:frontend_app/core/storage/secure_store.dart';

void main() {
  group('redactKey', () {
    test('masks secrets, never returns the raw token', () {
      expect(redactKey(null), '<none>');
      expect(redactKey(''), '<none>');
      expect(redactKey('ab'), '••••');
      expect(redactKey('sk-secret-12345'), 'sk-s…');
      // Never leaks the tail.
      expect(redactKey('sk-secret-12345').contains('secret'), false);
    });
  });

  group('AppTheme', () {
    test('builds light + dark themes with the brand orange primary', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(light.colorScheme.primary, isA<Color>());
      expect(dark.colorScheme.primary, isA<Color>());
      // Brand orange hue (~27°) in HSL.
      final hsl = HSLColor.fromColor(light.colorScheme.primary);
      expect((hsl.hue - 27).abs() < 2, true);
    });
  });
}
