import 'dart:io';

import 'package:html/parser.dart' as html_parser;

const String _privacyCanonicalPath = 'privacy.html';
const String _termsCanonicalPath = 'web/terms/index.html';

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

  final String privacyHtml = File(_privacyCanonicalPath).readAsStringSync();
  final String termsHtml = File(_termsCanonicalPath).readAsStringSync();
  final Map<String, String> generated = <String, String>{
    'legal.css': File('web/legal.css').readAsStringSync(),
    'privacy/index.html': _privacyRoute,
    'privacy-policy/index.html': _privacyCompatibilityRoute,
    'terms/index.html': termsHtml,
    'terms-of-service/index.html': _termsCompatibilityRoute,
    'assets/legal/privacy_policy.txt': _plainText(privacyHtml),
    'assets/legal/terms_of_service.html': termsHtml,
    'assets/legal/terms_of_service.txt': _plainText(termsHtml),
  };

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

String _plainText(String html) {
  final String text = html_parser.parse(html).body?.text ?? '';
  final List<String> lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((String line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((String line) => line.isNotEmpty)
      .toList(growable: false);
  return '${lines.join('\n\n')}\n';
}
