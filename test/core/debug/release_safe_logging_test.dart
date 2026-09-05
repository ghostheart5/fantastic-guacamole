import 'dart:io';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release-safe logging', () {
    test('normal release output contains only a fixed diagnostic code', () {
      final List<String> output = Logger.resolveLocalDiagnosticOutput(
        code: 'voice.playback_failed',
        debugMessage: 'person@example.com password=hunter2',
        exception: StateError('Bearer secret-token'),
        stackTrace: StackTrace.fromString(
          'package:fantastic_guacamole/voice.dart auth_token=stack-secret',
        ),
        debugMarker: 'VOICE_ERROR_MARKER',
        isDebugMode: false,
        verboseLogsEnabled: false,
      );

      expect(output, <String>['[ERROR][voice.playback_failed]']);
      expect(output.join('\n'), isNot(contains('person@example.com')));
      expect(output.join('\n'), isNot(contains('hunter2')));
      expect(output.join('\n'), isNot(contains('secret-token')));
      expect(output.join('\n'), isNot(contains('stack-secret')));
    });

    test('explicit verbose release output is detailed but redacted', () {
      final List<String> output = Logger.resolveLocalDiagnosticOutput(
        code: 'startup.flutter_framework_error',
        debugMessage: 'person@example.com password=hunter2',
        exception: StateError('Bearer secret-token'),
        stackTrace: StackTrace.fromString(
          'package:fantastic_guacamole/app.dart auth_token=stack-secret',
        ),
        debugMarker: 'FLUTTER_ERROR_MARKER',
        isDebugMode: false,
        verboseLogsEnabled: true,
      );
      final String joined = output.join('\n');

      expect(output, hasLength(3));
      expect(output.first, startsWith('FLUTTER_ERROR_MARKER >>>'));
      expect(output.last, 'FLUTTER_ERROR_MARKER <<<');
      expect(joined, contains('[redacted-email]'));
      expect(joined, contains('[redacted-password]'));
      expect(joined, contains('Bearer [redacted-token]'));
      expect(joined, contains('auth_token=[redacted-token]'));
      expect(joined, isNot(contains('person@example.com')));
      expect(joined, isNot(contains('hunter2')));
      expect(joined, isNot(contains('secret-token')));
      expect(joined, isNot(contains('stack-secret')));
    });

    test('debug builds retain detailed redacted diagnostics by default', () {
      final List<String> output = Logger.resolveLocalDiagnosticOutput(
        code: 'error_boundary.global_error',
        debugMessage: 'Useful debug context',
        exception: StateError('development failure'),
        stackTrace: StackTrace.fromString('package:chronospark/debug.dart:1'),
        isDebugMode: true,
        verboseLogsEnabled: false,
      );

      expect(output, hasLength(2));
      expect(output.first, contains('Useful debug context'));
      expect(output.first, contains('development failure'));
      expect(output.last, contains('package:chronospark/debug.dart:1'));
    });

    test('sensitive failure paths use Logger with typed diagnostic codes', () {
      const List<String> paths = <String>[
        'lib/system/voice/voice_service.dart',
        'lib/system/voice/speech_recognition_service.dart',
        'lib/system/voice/audio_interruption_service.dart',
        'lib/state/services/reflection_reminder_service.dart',
        'lib/ui/widgets/error_boundary_widget.dart',
        'lib/app/startup/startup_error_hooks.dart',
        'lib/app/startup/startup_stages.dart',
        'lib/app/startup/startup_coordinator.dart',
        'lib/app/startup/startup_preference_migration.dart',
      ];
      final RegExp invocationPattern = RegExp(
        r'Logger\.errorCode\(([\s\S]*?)\);',
      );
      final RegExp fixedCodePattern = RegExp(
        r'\bcode:\s*AppDiagnosticCode\.[a-z][A-Za-z0-9]*',
      );

      for (final String path in paths) {
        final String source = File(path).readAsStringSync();
        expect(source, isNot(contains('debugPrint(')), reason: path);
        expect(source, isNot(contains('Logger.error(')), reason: path);
        expect(source, isNot(contains('Logger.errorCategory(')), reason: path);

        final List<RegExpMatch> invocations = invocationPattern
            .allMatches(source)
            .toList(growable: false);
        expect(invocations, isNotEmpty, reason: path);
        for (final RegExpMatch invocation in invocations) {
          expect(
            invocation.group(1),
            matches(fixedCodePattern),
            reason: 'Diagnostic codes must be typed and non-sensitive: $path',
          );
        }
      }
    });

    test('typed diagnostic catalog has unique privacy-safe wire names', () {
      final List<String> names = AppDiagnosticCode.values
          .map((AppDiagnosticCode code) => code.wireName)
          .toList(growable: false);

      expect(names.toSet(), hasLength(names.length));
      for (final String name in names) {
        expect(name, matches(RegExp(r'^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$')));
        expect(name.length, lessThanOrEqualTo(64));
        expect(
          name,
          isNot(matches(RegExp(r'email|token|password|prompt|device|user_id'))),
        );
      }
    });

    test(
      'startup failure codes remain identifiable without private details',
      () {
        for (final AppDiagnosticCode code in AppDiagnosticCode.values.where(
          (code) => code.wireName.startsWith('startup.'),
        )) {
          expect(
            Logger.resolveLocalDiagnosticOutput(
              code: code.wireName,
              debugMessage: 'person@example.com password=private',
              exception: StateError('Bearer private-token'),
              isDebugMode: false,
              verboseLogsEnabled: false,
            ),
            <String>['[ERROR][${code.wireName}]'],
          );
        }
      },
    );
  });
}
