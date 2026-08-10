import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '_support/source_test_utils.dart';

void main() {
  group('Auth behavior contract', () {
    test('auth controller contains required session and credential flows', () {
      final File file = File(
        'lib/features/auth/application/auth_controller.dart',
      );
      expect(file.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(file);

      expect(text.contains('restoreSession('), isTrue);
      expect(text.contains('signInWithEmail('), isTrue);
      expect(text.contains('signUpWithEmail('), isTrue);
      expect(text.contains('signOut('), isTrue);
    });

    test('auth source includes email verification and phone flow paths', () {
      final String allAuth = SourceTestUtils.readAllConcatenated(
        'lib/features/auth',
      ).toLowerCase();

      expect(
        allAuth.contains('verify-email') || allAuth.contains('verifyemail'),
        isTrue,
      );
      expect(allAuth.contains('phone') || allAuth.contains('otp'), isTrue);
    });

    test('auth provider/controller exposes auth state and failure path', () {
      final String controller = SourceTestUtils.readText(
        File('lib/features/auth/application/auth_controller.dart'),
      );
      final String state = SourceTestUtils.readText(
        File('lib/features/auth/application/auth_state.dart'),
      );

      expect(controller.contains('AuthStatus.error'), isTrue);
      expect(controller.contains('_normalizeFailure'), isTrue);
      expect(state.contains('AuthStatus'), isTrue);
    });
  });
}
