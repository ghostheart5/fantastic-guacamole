import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authoritative evidence template defines all ordered mandatory stages',
    () {
      final Map<String, dynamic> template =
          jsonDecode(
                File(
                  'tool/release_gate/phase13_evidence_template.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final List<dynamic> stages = template['stages'] as List<dynamic>;
      expect(stages, hasLength(19));
      expect(
        (stages.first as Map<String, dynamic>)['name'],
        'repositoryIntegrity',
      );
      expect(
        (stages[9] as Map<String, dynamic>)['name'],
        'signedCandidateBuild',
      );
      expect(
        (stages[10] as Map<String, dynamic>)['name'],
        'binaryHashGeneration',
      );
      expect(
        (stages.last as Map<String, dynamic>)['name'],
        'independentReleaseApproval',
      );
    },
  );

  test('release workflows consume gated artifacts instead of rebuilding', () {
    final String android = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();
    final String web = File('.github/workflows/main.yml').readAsStringSync();
    expect(android, contains('resolve-authoritative-gate'));
    expect(web, contains('Assemble static public site'));
    expect(web, contains('cp -R site/. _site/'));
    expect(android, isNot(contains('flutter build appbundle')));
    expect(web, isNot(contains('flutter build web')));
  });

  test(
    'manifest validator blocks dirty, mismatched, unsigned, or connected-chat evidence',
    () {
      final String source = File(
        'scripts/authoritative_release_gate.ps1',
      ).readAsStringSync();
      expect(source, contains('working tree is dirty'));
      expect(source, contains('belongs to a different binary'));
      expect(source, contains('Human Root'));
      expect(source, contains('Staging'));
      expect(source, contains('chat isolation was not verified'));
      expect(source, contains('expired quarantine'));
      expect(source, contains('open P0 or P1 defect'));
    },
  );
}
