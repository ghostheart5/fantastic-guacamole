import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_apple_backend_mode.dart';

void main() {
  String encoded(List<String> defines) =>
      defines.map((value) => base64.encode(utf8.encode(value))).join(',');

  test('Apple build defaults to cloud and accepts explicit cloud mode', () {
    expect(appleBackendModeIssue(''), isNull);
    expect(
      appleBackendModeIssue(encoded(['CHRONOSPARK_BACKEND_MODE=cloud'])),
      isNull,
    );
    expect(
      appleBackendModeIssue(encoded(['CHRONOSPARK_BACKEND_MODE= cloud '])),
      isNull,
    );
    expect(appleBackendModeIssue(encoded(['UNRELATED=local'])), isNull);
  });

  test('Apple local build is blocked even without Firebase configuration', () {
    expect(
      appleBackendModeIssue(encoded(['CHRONOSPARK_BACKEND_MODE=local'])),
      contains('Android only'),
    );
  });

  test(
    'Apple mode parser rejects invalid input and contradictory definitions',
    () {
      for (final String value in ['LOCAL', '', 'unknown']) {
        expect(
          appleBackendModeIssue(encoded(['CHRONOSPARK_BACKEND_MODE=$value'])),
          isNotNull,
        );
      }
      expect(appleBackendModeIssue('%%%'), isNotNull);
      expect(appleBackendModeIssue(encoded(['BROKEN'])), isNotNull);
      expect(
        appleBackendModeIssue(
          encoded([
            'CHRONOSPARK_BACKEND_MODE=local',
            'CHRONOSPARK_BACKEND_MODE=cloud',
          ]),
        ),
        contains('Conflicting'),
      );
    },
  );

  test('both Apple build and embed phases run the mode guard first', () {
    for (final String platform in ['ios', 'macos']) {
      final String project = File(
        '$platform/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final List<RegExpMatch> phases = RegExp(
        r'shellScript = "([^\n]*)";',
      ).allMatches(project).toList();
      final List<String> flutterPhases = phases
          .map((match) => match.group(1)!)
          .where(
            (script) =>
                script.contains('xcode_backend.sh') ||
                script.contains('macos_assemble.sh'),
          )
          .toList();
      expect(flutterPhases, hasLength(2), reason: platform);
      for (final String script in flutterPhases) {
        expect(script, contains('validate_apple_backend_mode.dart'));
        final String command = platform == 'ios'
            ? 'xcode_backend.sh'
            : 'macos_assemble.sh';
        expect(
          script.indexOf('validate_apple_backend_mode.dart'),
          lessThan(script.indexOf(command)),
        );
        expect(script, contains(r'.dart\" && '));
      }
    }
  });
}
