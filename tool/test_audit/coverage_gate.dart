import 'dart:io';

Future<void> main(List<String> args) async {
  const defaultMin = 80.0;
  var minCoverage = defaultMin;

  for (final arg in args) {
    if (arg.startsWith('--min=')) {
      minCoverage = double.parse(arg.split('=').last);
    }
  }

  final coverageFile = File('coverage/lcov.info');
  if (!coverageFile.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run flutter test --coverage first.',
    );
    exitCode = 1;
    return;
  }

  final List<File> libFiles = _collectTestableLibFiles();
  if (libFiles.isEmpty) {
    stdout.writeln('No testable lib files found.');
    return;
  }

  final lines = coverageFile.readAsLinesSync();
  final hits = <String, int>{};
  final total = <String, int>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = _normalizeCoveragePath(line.substring(3));
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) {
        continue;
      }
      final count = int.parse(parts[1]);
      if (currentFile != null) {
        hits[currentFile] = (hits[currentFile] ?? 0) + (count > 0 ? 1 : 0);
        total[currentFile] = (total[currentFile] ?? 0) + 1;
      }
    }
  }

  final Map<String, ({int covered, int totalLines})> fileStats =
      <String, ({int covered, int totalLines})>{};
  for (final File file in libFiles) {
    final String relativePath = _normalizeFilePath(file.path);
    final int covered = hits[relativePath] ?? 0;
    final int measuredLines = total[relativePath] ?? 0;
    final int sourceLines = file.readAsLinesSync().length;
    final int totalLines = measuredLines > 0 ? measuredLines : sourceLines;
    fileStats[relativePath] = (covered: covered, totalLines: totalLines);
  }

  final List<String> sortedFiles = fileStats.keys.toList()
    ..sort((String a, String b) {
      final double aPct = _coveragePercent(fileStats[a]!);
      final double bPct = _coveragePercent(fileStats[b]!);
      final int percentOrder = aPct.compareTo(bPct);
      if (percentOrder != 0) {
        return percentOrder;
      }
      return a.compareTo(b);
    });

  int totalCovered = 0;
  int totalLines = 0;
  for (final stats in fileStats.values) {
    totalCovered += stats.covered;
    totalLines += stats.totalLines;
  }
  final double overall = totalLines == 0
      ? 100.0
      : (totalCovered / totalLines) * 100;

  stdout.writeln('Total coverage: ${overall.toStringAsFixed(2)}%');
  stdout.writeln('Threshold: ${minCoverage.toStringAsFixed(2)}%');
  for (final file in sortedFiles) {
    final stats = fileStats[file]!;
    final double percent = _coveragePercent(stats);
    stdout.writeln(
      '${percent.toStringAsFixed(2)}% (${stats.covered}/${stats.totalLines}) $file',
    );
  }

  if (overall < minCoverage) {
    stderr.writeln('Coverage below threshold.');
    exitCode = 1;
  }
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

String _normalizeCoveragePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  final int libIndex = normalized.indexOf('/lib/');
  if (libIndex != -1) {
    return normalized.substring(libIndex + 1);
  }
  if (normalized.startsWith('lib/')) {
    return normalized;
  }
  return normalized;
}

String _normalizeFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  final int libIndex = normalized.indexOf('/lib/');
  if (libIndex != -1) {
    return normalized.substring(libIndex + 1);
  }
  if (normalized.startsWith('lib/')) {
    return normalized;
  }
  return normalized;
}

double _coveragePercent(({int covered, int totalLines}) stats) {
  if (stats.totalLines == 0) {
    return 100.0;
  }
  return (stats.covered / stats.totalLines) * 100;
}
