import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/validate_maestro_flows.dart' as validator;

List<String> _stale(
  String commands,
  String corpus, {
  Set<String> typed = const <String>{},
}) => validator.staleTextFragments(
  loadYaml(commands),
  corpus.toLowerCase(),
  typedText: typed,
);

void main() {
  const String corpus = 'sign in a little space to think forgot password?';

  test('flags text a flow waits for or taps that the app no longer shows', () {
    expect(
      _stale('- tapOn: "ENTER SYSTEM"\n- assertVisible: "Sign in"', corpus),
      <String>['ENTER SYSTEM'],
    );
    expect(
      _stale(
        '- extendedWaitUntil:\n    visible: "(?:Sign in|ENTER SYSTEM)"',
        corpus,
      ),
      <String>['ENTER SYSTEM'],
    );
  });

  test('checks the literal parts of a regular expression', () {
    expect(
      _stale(r'- assertVisible: "(?s)^A little space.*think$"', corpus),
      isEmpty,
    );
    expect(
      _stale(
        '- runFlow:\n'
        '    when:\n'
        '      visible: "A human decision operating system"\n'
        '    commands:\n'
        '      - tapOn: "Sign in"',
        corpus,
      ),
      <String>['A human decision operating system'],
    );
  });

  test('ignores ids, absence checks, variables and typed or env data', () {
    expect(
      _stale(
        '- tapOn:\n    id: "login-email-field"\n'
        '- assertNotVisible: "ENTER SYSTEM"\n'
        '- assertVisible: "\${SAVED_ITEM}"\n'
        '- assertVisible: "(?s).*Sentinel one.*"',
        corpus,
        typed: <String>{'Sentinel one'},
      ),
      isEmpty,
    );
  });

  test('every text selector in .maestro still appears in lib', () {
    final String appCorpus = validator.loadAppTextCorpus(Directory('lib'));
    final List<File> flows = Directory('.maestro')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) {
          return f.path.endsWith('.yaml');
        })
        .toList();
    final Set<String> typed = <String>{};
    final List<dynamic> documents = <dynamic>[];
    for (final File file in flows) {
      for (final YamlDocument document in loadYamlDocuments(
        file.readAsStringSync(),
      )) {
        documents.add(document.contents);
        typed.addAll(validator.inputTexts(document.contents));
      }
    }
    final List<String> stale = <String>[
      for (final dynamic contents in documents)
        ...validator.staleTextFragments(contents, appCorpus, typedText: typed),
    ];
    expect(stale, isEmpty);
  });
}
