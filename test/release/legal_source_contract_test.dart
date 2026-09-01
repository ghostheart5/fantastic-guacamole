import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  String read(String path) => File(path).readAsStringSync();

  String plainText(String html) {
    final String text =
        html_parser.parse(html).querySelector('main')?.text ?? '';
    final List<String> lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((String line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    return '${lines.join('\n\n')}\n';
  }

  test('public and bundled legal copies match canonical documents', () {
    final String privacy = read('privacy.html');
    final String terms = read('web/terms/index.html');

    expect(read('assets/legal/privacy_policy.txt'), plainText(privacy));
    expect(plainText(read('privacy.html')), plainText(privacy));
    expect(read('terms/index.html'), terms);
    expect(read('assets/legal/terms_of_service.html'), terms);
    expect(read('assets/legal/terms_of_service.txt'), plainText(terms));
  });

  test('app-linked legal routes resolve to current documents', () {
    final String urls = read('lib/ui/constants/app_urls.dart');
    final String privacyRoute = read('privacy/index.html');
    final String termsRoute = read('terms/index.html');

    expect(urls, contains("privacy = '\$_githubPagesBase/privacy/'"));
    expect(urls, contains("terms = '\$_githubPagesBase/terms/'"));
    expect(privacyRoute, contains('url=../privacy.html'));
    expect(termsRoute, contains('<h1>ChronoSpark Terms of Service</h1>'));
    expect(termsRoute, isNot(contains('url=../terms.html')));
  });
}
