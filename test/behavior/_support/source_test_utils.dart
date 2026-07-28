import 'dart:convert';
import 'dart:io';

class SourceTestUtils {
  const SourceTestUtils._();

  static List<File> dartFilesUnder(
    String rootPath, {
    bool includeTestFiles = true,
  }) {
    final Directory root = Directory(rootPath);
    if (!root.existsSync()) {
      return <File>[];
    }

    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) {
          if (!file.path.endsWith('.dart')) {
            return false;
          }

          if (includeTestFiles) {
            return true;
          }

          final String normalized = normalizePath(file.path).toLowerCase();
          return !normalized.contains('/test/');
        })
        .toList(growable: false);
  }

  static List<File> filesUnder(String rootPath) {
    final Directory root = Directory(rootPath);
    if (!root.existsSync()) {
      return <File>[];
    }

    return root
        .listSync(recursive: true)
        .whereType<File>()
        .toList(growable: false);
  }

  static String normalizePath(String input) {
    return input.replaceAll('\\', '/');
  }

  static String readText(File file) {
    return file.readAsStringSync();
  }

  static String readUtf8Strict(File file) {
    final List<int> bytes = file.readAsBytesSync();
    return utf8.decode(bytes, allowMalformed: false);
  }

  static bool hasAnyToken(String text, List<String> tokens) {
    for (final String token in tokens) {
      if (text.contains(token)) {
        return true;
      }
    }
    return false;
  }

  static int countMatches(String text, RegExp regExp) {
    return regExp.allMatches(text).length;
  }

  static List<String> regexStrings(String text, RegExp regExp, int groupIndex) {
    return regExp
        .allMatches(text)
        .map((Match match) => match.group(groupIndex))
        .whereType<String>()
        .toList(growable: false);
  }

  static String readAllConcatenated(String rootPath) {
    final StringBuffer buffer = StringBuffer();
    for (final File file in dartFilesUnder(rootPath)) {
      buffer.writeln(normalizePath(file.path));
      buffer.writeln(readText(file));
    }
    return buffer.toString();
  }
}
