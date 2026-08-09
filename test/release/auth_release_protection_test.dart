import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('Auth release protection', () {
    test('auth controller paths exist for restore signin signup signout', () {
      final File authController = File('lib/features/auth/application/auth_controller.dart');
      expect(authController.existsSync(), isTrue);
      final String text = SourceTestUtils.readText(authController);

      expect(text.contains('restoreSession('), isTrue);
      expect(text.contains('signInWithEmail('), isTrue);
      expect(text.contains('signUpWithEmail('), isTrue);
      expect(text.contains('signOut('), isTrue);
    });

    test('auth source exposes error path and auth state surface', () {
      final String appText = SourceTestUtils.readAllConcatenated('lib/features/auth').toLowerCase();
      expect(appText.contains('authstatus'), isTrue);
      expect(appText.contains('error'), isTrue);
      expect(appText.contains('watchsession') || appText.contains('getcurrentsession'), isTrue);
    });

    test('auth source includes verify or reset and optional phone path wiring', () {
      final String authText = SourceTestUtils.readAllConcatenated('lib/features/auth').toLowerCase();
      final String loginText = SourceTestUtils.readText(File('lib/features/auth/ui/login_screen.dart')).toLowerCase();

      expect(authText.contains('sendpasswordreset') || authText.contains('verify'), isTrue);

      if (loginText.contains('phone')) {
        expect(authText.contains('phone'), isTrue, reason: 'Phone appears in login UI but no phone path found in auth source.');
      }
    });

    test('signup does not automatically resend verification and callback config is documented', () {
      final String authGate = SourceTestUtils.readText(
        File('lib/features/auth/screens/auth_gate.dart'),
      );
      final String signUpHandler = authGate.substring(
        authGate.indexOf('if (_signUpMode)'),
        authGate.indexOf('await widget.authService.signIn('),
      );
      final String env = SourceTestUtils.readText(File('lib/config/env.dart'));
      final String envExample = SourceTestUtils.readText(File('.env.example'));
        final String readme = SourceTestUtils
          .readText(File('README.md'))
          .replaceAll(RegExp(r'\s+'), ' ');

      expect(signUpHandler.contains('sendEmailVerification'), isFalse);
      expect(env.contains('CHRONOSPARK_OAUTH_REDIRECT_URL'), isTrue);
      expect(env.contains('CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL'), isTrue);
      expect(env.contains('https://chronospark.app/app/auth/callback'), isTrue);
      expect(envExample.contains('CHRONOSPARK_OAUTH_REDIRECT_URL=chronospark://auth-callback'), isTrue);
      expect(envExample.contains('CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL=chronospark://auth-callback'), isTrue);
      expect(readme.contains('Supabase Auth production setup'), isTrue);
      expect(readme.contains('SMTP provider or Send Email Auth Hook'), isTrue);
      expect(readme.contains('redirect allowlist'), isTrue);
    });

    test('auth source does not contain hard-coded credentials', () {
      final List<String> offenders = <String>[];
      final List<RegExp> riskyPatterns = <RegExp>[
        RegExp(r'service_role', caseSensitive: false),
        RegExp(r'sb_secret', caseSensitive: false),
        RegExp(r'private[_-]?key', caseSensitive: false),
        RegExp(r'bearer\s+[a-z0-9\-\._~\+/]+=*', caseSensitive: false),
      ];

      for (final File file in SourceTestUtils.dartFilesUnder('lib/features/auth')) {
        final String path = SourceTestUtils.normalizePath(file.path);
        final String text = SourceTestUtils.readText(file);
        final bool allowEnv = text.contains('String.fromEnvironment');
        for (final RegExp pattern in riskyPatterns) {
          if (pattern.hasMatch(text) && !allowEnv) {
            offenders.add(path);
            break;
          }
        }
      }

      expect(offenders, isEmpty, reason: 'Auth files with possible hard-coded credentials: $offenders');
    });
  });
}
