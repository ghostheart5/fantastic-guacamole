import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/validate_maestro_flows.dart' as validator;
import '../../tool/validate_maestro_flows.dart' show AppText;

AppText _app(String source) => AppText(<String>[source]);

List<String> _stale(
  String commands,
  AppText app, {
  Set<String> typed = const <String>{},
}) => validator.staleTextFragments(loadYaml(commands), app, typedText: typed);

void main() {
  final AppText corpus = _app(r'''
const a = 'Sign in';
const b = 'A little space to think';
const c = 'Forgot Password?';
const e = 'Don\'t lose it';
const f = 'Continue to ${x}' 'profile';
// 'Only in a comment'
/* 'Block comment text' */
const g = 'CONTINUE TO LOGIN';
const h = 'CONTINUE TO PROFILE';
''');

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

  test('checks whole phrases, not short words found inside other text', () {
    // "Sign in again and retry." must not satisfy "Sign in" once the button
    // label itself is gone.
    final AppText app = _app("const d = 'Sign in again and retry.';");
    expect(_stale('- tapOn: "Sign in"', app), <String>['Sign in']);
    // Text that only appears in a comment is not shown to anyone.
    expect(_stale('- tapOn: "Only in a comment"', corpus), <String>[
      'Only in a comment',
    ]);
    expect(_stale('- tapOn: "Block comment text"', corpus), isNotEmpty);
    // Alternatives are expanded and each is checked as a phrase.
    expect(
      _stale(r'- tapOn: "^CONTINUE TO (?:LOGIN|PROFILE)$"', corpus),
      isEmpty,
    );
    expect(
      _stale(r'- tapOn: "^CONTINUE TO (?:LOGIN|SETUP)$"', corpus),
      <String>['CONTINUE TO SETUP'],
    );
    expect(
      _stale(r'- assertVisible: "(?s)^A little.*think$"', corpus),
      isEmpty,
    );
  });

  test('matches literals with apostrophes, a trailing ? and interpolation', () {
    expect(_stale('- assertVisible: "Don\'t lose it"', corpus), isEmpty);
    expect(_stale('- assertVisible: "Don’t lose it"', corpus), isEmpty);
    expect(_stale('- assertVisible: "Forgot Password?"', corpus), isEmpty);
    expect(_stale('- assertVisible: "Continue to"', corpus), isEmpty);
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

  test('an allowlisted label is only trusted while its builder exists', () {
    final String builder = validator.composedLabels['save goal']!;
    expect(_stale('- tapOn: "Save goal"', _app('x')), isEmpty);
    expect(
      validator.staleComposedLabels(_app('nothing here')),
      contains('save goal'),
    );
    expect(
      validator.staleComposedLabels(_app(builder)),
      isNot(contains('save goal')),
    );
  });

  test(
    'every composed label in the allowlist still has its builder in lib',
    () {
      expect(
        validator.staleComposedLabels(AppText.load(Directory('lib'))),
        isEmpty,
      );
    },
  );

  test('every text selector in .maestro still appears in lib', () {
    final AppText app = AppText.load(Directory('lib'));
    final List<File> flows = Directory('.maestro')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.yaml'))
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
        ...validator.staleTextFragments(contents, app, typedText: typed),
    ];
    expect(stale, isEmpty);
  });
}
