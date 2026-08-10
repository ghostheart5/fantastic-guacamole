import 'dart:io';

void main() {
  final List<File> libFiles = _collectTestableLibFiles();
  if (libFiles.isEmpty) {
    stdout.writeln('No testable lib files found.');
    return;
  }

  final File lcovFile = File('coverage/lcov.info');
  final Map<String, ({int covered, int measured})> coverage =
      lcovFile.existsSync()
      ? _parseLcov(lcovFile.readAsLinesSync())
      : <String, ({int covered, int measured})>{};

  final List<({String path, int covered, int total})> rows =
      <({String path, int covered, int total})>[];

  for (final File file in libFiles) {
    final String path = _normalizeFilePath(file.path);
    final ({int covered, int measured})? lcov = coverage[path];
    final int sourceLineCount = file.readAsLinesSync().length;
    final int total = (lcov?.measured ?? 0) > 0
        ? lcov!.measured
        : sourceLineCount;
    final int covered = lcov?.covered ?? 0;
    rows.add((path: path, covered: covered, total: total));
  }

  rows.sort((a, b) {
    final double aPct = _pct(a.covered, a.total);
    final double bPct = _pct(b.covered, b.total);
    final int byPct = aPct.compareTo(bPct);
    if (byPct != 0) {
      return byPct;
    }
    return a.path.compareTo(b.path);
  });

  int totalCovered = 0;
  int totalLines = 0;

  for (final row in rows) {
    totalCovered += row.covered;
    totalLines += row.total;
    final String pct = _pct(row.covered, row.total).toStringAsFixed(2);
    stdout.writeln('$pct% (${row.covered}/${row.total}) ${row.path}');
  }

  final double overall = _pct(totalCovered, totalLines);
  stdout.writeln('---');
  stdout.writeln(
    'Overall lib coverage: ${overall.toStringAsFixed(2)}% ($totalCovered/$totalLines)',
  );
}

List<File> _collectTestableLibFiles() {
  final Directory libDir = Directory('lib');
  if (!libDir.existsSync()) {
    return <File>[];
  }

  return libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) {
        final String path = _normalizeFilePath(file.path);
        if (!path.endsWith('.dart')) {
          return false;
        }
        if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) {
          return false;
        }
        if (path.endsWith('firebase_options.dart')) {
          return false;
        }
        if (path.endsWith('generated_plugin_registrant.dart')) {
          return false;
        }
        return true;
      })
      .toList(growable: false);
}

Map<String, ({int covered, int measured})> _parseLcov(List<String> lines) {
  final Map<String, int> covered = <String, int>{};
  final Map<String, int> measured = <String, int>{};
  String? current;

  for (final String line in lines) {
    if (line.startsWith('SF:')) {
      current = _normalizeCoveragePath(line.substring(3));
      continue;
    }

    if (current == null || !line.startsWith('DA:')) {
      continue;
    }

    final List<String> parts = line.substring(3).split(',');
    if (parts.length < 2) {
      continue;
    }

    final int count = int.tryParse(parts[1]) ?? 0;
    measured[current] = (measured[current] ?? 0) + 1;
    if (count > 0) {
      covered[current] = (covered[current] ?? 0) + 1;
    }
  }

  final Map<String, ({int covered, int measured})> result =
      <String, ({int covered, int measured})>{};
  for (final entry in measured.entries) {
    result[entry.key] = (
      covered: covered[entry.key] ?? 0,
      measured: entry.value,
    );
  }
  return result;
}

String _normalizeCoveragePath(String input) {
  final String normalized = input.replaceAll('\\', '/');
  final int libIndex = normalized.indexOf('/lib/');
  if (libIndex != -1) {
    return normalized.substring(libIndex + 1);
  }
  if (normalized.startsWith('lib/')) {
    return normalized;
  }
  return normalized;
}

String _normalizeFilePath(String input) {
  final String normalized = input.replaceAll('\\', '/');
  final int libIndex = normalized.indexOf('/lib/');
  if (libIndex != -1) {
    return normalized.substring(libIndex + 1);
  }
  if (normalized.startsWith('lib/')) {
    return normalized;
  }
  return normalized;
}

double _pct(int covered, int total) {
  if (total <= 0) {
    return 100.0;
  }
  return (covered / total) * 100;
}
