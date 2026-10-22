import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;

void main() {
  String read(String path) => File(path).readAsStringSync();

  test(
    'privacy copies describe bounded local Chat continuity and explicit controls',
    () {
      for (final path in [
        'web/privacy/index.html',
        'privacy.html',
        'assets/legal/privacy_policy.html',
        'assets/legal/privacy_policy.txt',
      ]) {
        final source = read(path);
        for (final phrase in [
          'Chat saves up to 40 recent messages',
          'account-scoped secure storage on this device',
          'restarting the app',
          'excluded from planning backups and cloud sync',
          'Clear conversation',
          'Copy conversation',
          'clipboard',
          "Signing out preserves this account's saved Chat history on the device",
          'signing back into the same account restores access',
          "explicitly clearing this account's local data removes its saved Chat history",
          'The last six messages',
          'even when saved planning sources are off',
          'Choose a step keeps a separate conversation only while its screen is open',
        ]) {
          expect(source, contains(phrase), reason: path);
        }
        expect(
          source,
          isNot(contains('does not provide a saved transcript archive')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('remains available while its screen remains open')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('Signing out or clearing this account')),
          reason: path,
        );
        expect(
          source,
          contains('default 30-day retention period'),
          reason: path,
        );
        expect(source, contains('15-minute recovery window'), reason: path);
      }
    },
  );

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
    final chat = read(
      'lib/features/assistant/ui/assistant_conversation_screen.history.dart',
    );
    expect(
      chat,
      contains('Signing out keeps this account’s saved history on the device'),
    );
    expect(
      chat,
      contains('signing back into the same account restores access'),
    );
    expect(
      chat,
      contains(
        'Al cerrar sesión, el historial guardado de esta cuenta permanece en el dispositivo',
      ),
    );
    expect(chat, isNot(contains('cleared or you sign out')));
    expect(
      chat,
      isNot(
        contains(
          'Se borran al limpiar los datos locales de esta cuenta o cerrar sesión',
        ),
      ),
    );
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

  test(
    'cloud disclosure separates confirmed full snapshots from legacy backups',
    () {
      final document = html_parser.parse(read('web/privacy/index.html'));
      final heading = document
          .querySelectorAll('h2')
          .firstWhere(
            (element) => element.text == 'Optional encrypted cloud backup',
          );
      final upload = heading.nextElementSibling!.text;
      final limits = heading.nextElementSibling!.nextElementSibling!.text;
      expect(
        upload,
        contains('tasks, profile information, and account preferences'),
      );
      for (final domain in [
        'goals',
        'Daily Rhythms',
        'notes',
        'occurrence history',
        'decision outcomes',
      ]) {
        expect(
          upload,
          isNot(contains(domain)),
          reason: '$domain is not in the contained upload',
        );
        expect(
          limits,
          contains(domain),
          reason: '$domain must be disclosed for confirmed full backups',
        );
      }
      expect(limits, contains('cannot be restored from this cloud backup'));
      expect(limits, contains('lost after uninstalling'));
      expect(limits, contains('and confirm'));
      expect(limits, contains('replaces the previous cloud snapshot'));
      expect(
        limits,
        contains('Private memories and Person Context are excluded'),
      );
    },
  );

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
      const String installLink =
          '<a href="https://play.google.com/store/apps/details?id=com.ghostheart5.chronospark">Google Play</a>';
      if (path == 'web/support/index.html') {
        expect(installLink.allMatches(source), hasLength(1), reason: path);
      }
      final String brandingSource = path == 'web/support/index.html'
          ? source.replaceAll(installLink, '')
          : source;
      expect(source, contains('Axiomara'), reason: path);
      expect(source.toLowerCase(), contains('marketplace'), reason: path);
      expect(brandingSource, isNot(contains('ChronoSpark')), reason: path);
      expect(brandingSource, isNot(contains('chronospark')), reason: path);
      expect(brandingSource, isNot(contains('Google Play')), reason: path);
      expect(brandingSource, isNot(contains('play.google.com')), reason: path);
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
      contains('This site does not distribute APK files.'),
    );
    final String productSite = read('site/index.html');
    expect(productSite, contains('Reflection and planning'));
    expect(productSite, contains('Tools for your day'));
    expect(productSite, contains('Choose a step'));
    expect(productSite, contains('SI Chat'));
    expect(productSite, contains('Today'));
    expect(productSite, contains('publicly available'));
    expect(productSite, isNot(contains('Closed testing')));
    expect(productSite, isNot(contains('tester support')));
    expect(productSite, contains('Install and update Axiomara'));
    expect(productSite, contains('does not provide an application download'));
  });
}
