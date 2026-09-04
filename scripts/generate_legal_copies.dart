import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

const String _manifestPath = 'legal/legal_documents.json';

const String _privacyRoute = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Privacy Policy</title>
  <meta http-equiv="refresh" content="0; url=../privacy.html" />
  <link rel="canonical" href="https://ghostheart5.github.io/fantastic-guacamole/privacy/" />
</head>
<body>
  <p>Redirecting to <a href="../privacy.html">privacy policy</a>...</p>
</body>
</html>
''';

const String _privacyCompatibilityRoute = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Privacy Policy</title>
  <meta http-equiv="refresh" content="0; url=../privacy/" />
  <link rel="canonical" href="https://ghostheart5.github.io/fantastic-guacamole/privacy/" />
</head>
<body>
  <p>Redirecting to <a href="../privacy/">privacy policy</a>...</p>
</body>
</html>
''';

const String _termsCompatibilityRoute = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Terms of Service</title>
  <meta http-equiv="refresh" content="0; url=../terms/" />
  <link rel="canonical" href="https://ghostheart5.github.io/fantastic-guacamole/terms/" />
</head>
<body>
  <p>Redirecting to <a href="../terms/">terms of service</a>...</p>
</body>
</html>
''';

void main(List<String> arguments) {
  final bool checkOnly = arguments.contains('--check');
  if (arguments.any((String value) => value != '--check')) {
    stderr.writeln(
      'Usage: dart run scripts/generate_legal_copies.dart [--check]',
    );
    exitCode = 64;
    return;
  }

  final Map<String, String> generated = <String, String>{
    'privacy/index.html': _privacyRoute,
    'privacy-policy/index.html': _privacyCompatibilityRoute,
    'terms-of-service/index.html': _termsCompatibilityRoute,
  };
  final Map<String, dynamic> manifest = _readManifest();
  final List<dynamic> documents = manifest['documents'] as List<dynamic>;
  final Set<String> documentIds = <String>{};
  for (final dynamic rawDocument in documents) {
    final Map<String, dynamic> document = rawDocument as Map<String, dynamic>;
    final String id = document['id'] as String;
    if (!documentIds.add(id)) {
      throw FormatException('Duplicate legal document id: $id');
    }
    final String sourcePath = document['source'] as String;
    final String source = File(sourcePath).readAsStringSync();
    for (final dynamic rawOutput in document['outputs'] as List<dynamic>) {
      final Map<String, dynamic> output = rawOutput as Map<String, dynamic>;
      final String path = output['path'] as String;
      final String format = output['format'] as String;
      String content = switch (format) {
        'html' => source,
        'text' => _plainText(source),
        _ => throw FormatException('Unsupported legal output format: $format'),
      };
      final Map<String, dynamic> replacements =
          (output['replacements'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      for (final MapEntry<String, dynamic> replacement
          in replacements.entries) {
        content = content.replaceAll(
          replacement.key,
          replacement.value as String,
        );
      }
      if (generated.containsKey(path)) {
        throw FormatException('Duplicate generated legal output: $path');
      }
      generated[path] = content;
    }
  }
  for (final dynamic rawCopy in manifest['sharedCopies'] as List<dynamic>) {
    final Map<String, dynamic> copy = rawCopy as Map<String, dynamic>;
    final String sourcePath = copy['source'] as String;
    final String outputPath = copy['path'] as String;
    generated[outputPath] = File(sourcePath).readAsStringSync();
  }

  final List<String> drifted = <String>[];
  for (final MapEntry<String, String> entry in generated.entries) {
    final File file = File(entry.key);
    final String expected = entry.value;
    if (checkOnly) {
      if (!file.existsSync() || file.readAsStringSync() != expected) {
        drifted.add(entry.key);
      }
      continue;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(expected);
  }

  if (drifted.isNotEmpty) {
    stderr.writeln('Generated legal copies are stale: ${drifted.join(', ')}');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    checkOnly
        ? 'Legal copies match their canonical sources.'
        : 'Generated ${generated.length} legal copies.',
  );
}

Map<String, dynamic> _readManifest() {
  final Object? decoded = jsonDecode(File(_manifestPath).readAsStringSync());
  if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
    throw const FormatException('Unsupported legal document manifest.');
  }
  final Object? documents = decoded['documents'];
  final Object? sharedCopies = decoded['sharedCopies'];
  if (documents is! List<dynamic> ||
      documents.length != 4 ||
      sharedCopies is! List<dynamic>) {
    throw const FormatException(
      'Legal manifest must define four documents and shared copies.',
    );
  }
  return decoded;
}

String _plainText(String html) {
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
