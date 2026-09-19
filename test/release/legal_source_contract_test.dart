import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  String read(String path) => File(path).readAsStringSync();

  String plainText(String html) {
    final String mainHtml =
        html_parser.parse(html).querySelector('main')?.innerHtml ?? '';
    final String structured = mainHtml
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li(?:\s[^>]*)?>', caseSensitive: false), '\n- ')
        .replaceAll(
          RegExp(
            r'</(?:address|article|dd|div|dl|dt|h[1-6]|li|ol|p|section|ul)>',
            caseSensitive: false,
          ),
          '\n\n',
        );
    final String text = html_parser.parseFragment(structured).text ?? '';
    final List<String> lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    return '${lines.join('\n\n')}\n';
  }

  test('manifest owns four public documents and every derivative matches', () {
    final Map<String, dynamic> manifest =
        jsonDecode(read('legal/legal_documents.json')) as Map<String, dynamic>;
    expect(manifest['schemaVersion'], 1);
    final List<dynamic> documents = manifest['documents'] as List<dynamic>;
    expect(
      documents
          .map(
            (dynamic value) => (value as Map<String, dynamic>)['id'] as String,
          )
          .toSet(),
      <String>{'privacy', 'terms', 'support', 'delete-account'},
    );

    for (final dynamic rawDocument in documents) {
      final Map<String, dynamic> document = rawDocument as Map<String, dynamic>;
      final String source = read(document['source'] as String);
      expect(document['publicRoute'], startsWith('/'));
      for (final dynamic rawOutput in document['outputs'] as List<dynamic>) {
        final Map<String, dynamic> output = rawOutput as Map<String, dynamic>;
        String expected = switch (output['format']) {
          'html' => source,
          'text' => plainText(source),
          final Object? format => throw StateError('Unknown format: $format'),
        };
        final Map<String, dynamic> replacements =
            (output['replacements'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
        for (final MapEntry<String, dynamic> replacement
            in replacements.entries) {
          expected = expected.replaceAll(
            replacement.key,
            replacement.value as String,
          );
        }
        expect(read(output['path'] as String), expected);
      }
    }

    for (final dynamic rawCopy in manifest['sharedCopies'] as List<dynamic>) {
      final Map<String, dynamic> copy = rawCopy as Map<String, dynamic>;
      expect(read(copy['path'] as String), read(copy['source'] as String));
    }
  });

  test('app-linked legal routes resolve to current documents', () {
    final String urls = read('lib/ui/constants/app_urls.dart');
    final String privacyRoute = read('web/privacy/index.html');
    final String termsRoute = read('web/terms/index.html');

    expect(urls, contains("privacy = '\$_githubPagesBase/privacy/'"));
    expect(urls, contains("terms = '\$_githubPagesBase/terms/'"));
    expect(privacyRoute, contains('<h1>Privacy Policy</h1>'));
    expect(termsRoute, contains('<h1>Terms of Service</h1>'));
    expect(termsRoute, isNot(contains('url=../terms.html')));
  });

  test('privacy policy discloses OAuth account details', () {
    final String privacy = read('web/privacy/index.html');

    expect(privacy, contains('display name'));
    expect(privacy, contains('profile-image URL'));
    expect(privacy, contains('Account details'));
    expect(privacy, contains('sign-in provider identifier'));
  });

  test('public surfaces disclose billing without retired branding', () {
    for (final String path in <String>[
      'web/privacy/index.html',
      'web/terms/index.html',
      'web/support/index.html',
      'web/delete-account/index.html',
    ]) {
      final String source = read(path);
      expect(source, contains('Axiomara'), reason: path);
      expect(source.toLowerCase(), contains('marketplace'), reason: path);
      expect(source, isNot(contains('ChronoSpark')), reason: path);
      expect(source, isNot(contains('chronospark')), reason: path);
      expect(source, isNot(contains('Google Play')), reason: path);
      expect(source, isNot(contains('play.google.com')), reason: path);
      expect(
        source,
        isNot(contains('contained public configuration')),
        reason: path,
      );
    }
    for (final String path in <String>[
      'web/privacy/index.html',
      'web/terms/index.html',
    ]) {
      final String source = read(path);
      expect(source, contains('Anthropic'), reason: path);
      expect(source, contains('before confirmation'), reason: path);
    }
    for (final String path in <String>[
      'web/terms/index.html',
      'web/support/index.html',
      'web/delete-account/index.html',
    ]) {
      expect(read(path), contains('does not cancel'), reason: path);
    }
    expect(
      read('web/support/index.html'),
      contains('does not provide an APK or public download'),
    );
    final String productSite = read('site/index.html');
    expect(productSite, contains('The Human Decision OS'));
    expect(productSite, contains('Nine connected systems'));
    expect(productSite, contains('Smart Planner'));
    expect(productSite, contains('SI Console'));
    expect(productSite, contains('Nexus'));
    expect(productSite, contains('invited closed testing'));
    expect(productSite, contains('does not provide an application download'));
  });
}
