import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../behavior/_support/source_test_utils.dart';

void main() {
  group('P2-3 observability hardening contract', () {
    test('global crash handlers remain wired to diagnostics and crash reporting', () {
      final File bootstrapFile = File('lib/app/startup/app_bootstrap.dart');
      expect(bootstrapFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(bootstrapFile);

      expect(text.contains('runZonedGuarded(() async {'), isTrue);
      expect(text.contains('FlutterError.onError = (errorDetails) {'), isTrue);
      expect(
        text.contains(
          'PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {',
        ),
        isTrue,
      );
      expect(text.contains('RuntimeDiagnostics.record('), isTrue);
      expect(text.contains('ErrorBoundary.reportGlobalError('), isTrue);
      expect(
        text.contains(
          'FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);',
        ),
        isTrue,
      );
      expect(
        text.contains(
          'FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);',
        ),
        isTrue,
      );
    });

    test('voice telemetry event spine remains present in smart coach', () {
      final File coachFile = File(
        'lib/features/home/ui/smart_coach_screen.dart',
      );
      expect(coachFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(coachFile);

      expect(text.contains("'voice_mic_tapped'"), isTrue);
      expect(text.contains("'voice_permission_result'"), isTrue);
      expect(text.contains("'voice_listening_started'"), isTrue);
      expect(text.contains("'voice_capture_result'"), isTrue);
      expect(text.contains("'voice_command_parsed'"), isTrue);
      expect(text.contains("'voice_command_routed'"), isTrue);
      expect(text.contains("'voice_timeline_summary'"), isTrue);
    });

    test('session recovery failures are observable but non-fatal', () {
      final File sessionFile = File(
        'lib/state/services/session_recovery_service.dart',
      );
      expect(sessionFile.existsSync(), isTrue);

      final String text = SourceTestUtils.readText(sessionFile);

      expect(
        text.contains(
          'Logger.warn(\'Session recovery: saveState failed (non-fatal).\');',
        ),
        isTrue,
      );
      expect(
        text.contains(
          'Logger.warn(\'Session recovery: loadState failed (non-fatal).\');',
        ),
        isTrue,
      );
      expect(
        text.contains(
          'Logger.warn(\'Session recovery: clearDraft failed (non-fatal).\');',
        ),
        isTrue,
      );
      expect(
        text.contains(
          'Logger.warn(\'Session recovery: clearAll failed (non-fatal).\');',
        ),
        isTrue,
      );
      expect(text.contains('RuntimeDiagnostics.record('), isTrue);
      expect(text.contains('return null;'), isTrue);
    });
  });
}
