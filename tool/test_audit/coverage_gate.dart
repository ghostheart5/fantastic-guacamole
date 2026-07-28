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
    stderr.writeln('coverage/lcov.info not found. Run flutter test --coverage first.');
    exitCode = 1;
    return;
  }

  final lines = coverageFile.readAsLinesSync();
  final hits = <String, int>{};
  final total = <String, int>{};
  String? currentFile;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      int.parse(parts[0]);
      final count = int.parse(parts[1]);
      if (currentFile != null) {
        hits[currentFile] = (hits[currentFile] ?? 0) + (count > 0 ? 1 : 0);
        total[currentFile] = (total[currentFile] ?? 0) + 1;
      }
    }
  }

  final fileStats = <String, double>{};
  for (final entry in total.entries) {
    if (entry.key.contains('/lib/')) {
      final covered = hits[entry.key] ?? 0;
      final totalLines = entry.value;
      fileStats[entry.key] = totalLines == 0 ? 100 : covered / totalLines * 100;
    }
  }

  final libFiles = fileStats.keys.toList()..sort();
  final overall = libFiles.isEmpty
      ? 100.0
      : libFiles.map((file) => fileStats[file]!).reduce((a, b) => a + b) / libFiles.length;

  stdout.writeln('Total coverage: ${overall.toStringAsFixed(2)}%');
  stdout.writeln('Threshold: ${minCoverage.toStringAsFixed(2)}%');
  for (final file in libFiles) {
    stdout.writeln('${fileStats[file]!.toStringAsFixed(2)}% $file');
  }

  if (overall < minCoverage) {
    stderr.writeln('Coverage below threshold.');
    exitCode = 1;
  }
}
