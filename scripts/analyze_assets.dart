import 'dart:convert';
import 'dart:io';

void main() async {
  final Directory assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    stderr.writeln('Error: assets directory not found');
    exit(1);
  }

  final List<FileReport> files = <FileReport>[];
  int totalBytes = 0;

  await for (final FileSystemEntity entity in assetsDir.list(recursive: true)) {
    if (entity is File) {
      final int sizeBytes = entity.lengthSync();
      totalBytes += sizeBytes;
      final String path = entity.path.replaceFirst('assets/', '');
      files.add(FileReport(path, sizeBytes));
    }
  }

  files.sort((FileReport a, FileReport b) => b.sizeBytes.compareTo(a.sizeBytes));

  stdout.writeln('=== CHRONOSPARK ASSET ANALYSIS ===\n');
  stdout.writeln('Top 30 largest assets:');
  stdout.writeln('');

  final List<FileReport> top30 = files.take(30).toList();
  double cumulativeMb = 0;

  for (int i = 0; i < top30.length; i++) {
    final FileReport file = top30[i];
    final double sizeMb = file.sizeBytes / (1024 * 1024);
    cumulativeMb += sizeMb;
    final String category = _categorizeFile(file.path);
    final String risk = _assessRisk(file.path, file.sizeBytes);

    stdout.writeln(
      '${(i + 1).toString().padLeft(2)}. ${sizeMb.toStringAsFixed(2)} MB | ${file.path.padRight(50)} | $category | $risk',
    );
  }

  stdout.writeln('');
  stdout.writeln(
    'Total assets: ${files.length} files | ${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
  );
  stdout.writeln('Top 30 cumulative: ${cumulativeMb.toStringAsFixed(2)} MB');

  final List<String> recommendations = _generateRecommendations(files);
  if (recommendations.isNotEmpty) {
    stdout.writeln('\n=== OPTIMIZATION RECOMMENDATIONS ===\n');
    for (final String rec in recommendations) {
      stdout.writeln('⚠ $rec');
    }
  }

  _generateOptimizationReport(files);
}

String _categorizeFile(String path) {
  if (path.contains('backgrounds')) {
    return 'background';
  } else if (path.contains('icons') || path.contains('icon')) {
    return 'icon';
  } else if (path.contains('audio') || path.endsWith('.wav') || path.endsWith('.mp3')) {
    return 'audio';
  } else if (path.contains('overlays')) {
    return 'overlay';
  } else if (path.contains('fonts')) {
    return 'font';
  }
  return 'other';
}

String _assessRisk(String path, int sizeBytes) {
  final double sizeMb = sizeBytes / (1024 * 1024);
  final String category = _categorizeFile(path);

  if (category == 'icon' && sizeMb > 0.5) {
    return 'HIGH - icons should be < 200 KB';
  }
  if (category == 'background' && sizeMb > 1.2) {
    return 'MEDIUM - backgrounds are large; consider WebP or compression';
  }
  if (category == 'overlay' && sizeMb > 0.3) {
    return 'MEDIUM - overlays should be lightweight';
  }
  if (sizeMb > 2.0) {
    return 'HIGH - very large; investigate optimization';
  }
  return 'OK';
}

List<String> _generateRecommendations(List<FileReport> files) {
  final List<String> recs = <String>[];

  final double totalMb = files.fold(
    0.0,
    (double sum, FileReport f) => sum + (f.sizeBytes / (1024 * 1024)),
  );
  if (totalMb > 20) {
    recs.add(
      'Total asset size is ${totalMb.toStringAsFixed(1)} MB; consider reducing below 15 MB for faster startup.',
    );
  }

  final List<FileReport> largeIcons = files.where((FileReport f) {
    final String cat = _categorizeFile(f.path);
    return cat == 'icon' && f.sizeBytes > 500000;
  }).toList();

  if (largeIcons.isNotEmpty) {
    recs.add(
      '${largeIcons.length} icons exceed 500 KB; convert to vector (SVG) or reduce resolution.',
    );
  }

  final List<FileReport> largeBackgrounds = files.where((FileReport f) {
    final String cat = _categorizeFile(f.path);
    return cat == 'background' && f.sizeBytes > 1500000;
  }).toList();

  if (largeBackgrounds.isNotEmpty) {
    recs.add(
      '${largeBackgrounds.length} backgrounds exceed 1.5 MB; convert to WebP or reduce quality.',
    );
  }

  return recs;
}

void _generateOptimizationReport(List<FileReport> files) {
  final Map<String, List<FileReport>> byCategory = <String, List<FileReport>>{};

  for (final FileReport file in files) {
    final String category = _categorizeFile(file.path);
    byCategory.putIfAbsent(category, () => <FileReport>[]);
    byCategory[category]!.add(file);
  }

  final Map<String, dynamic> report = <String, dynamic>{
    'timestamp': DateTime.now().toIso8601String(),
    'summary': <String, dynamic>{
      'totalFiles': files.length,
      'totalSizeMb': (files.fold(
        0.0,
        (double sum, FileReport f) => sum + (f.sizeBytes / (1024 * 1024)),
      )).toStringAsFixed(2),
    },
    'byCategory': <String, dynamic>{},
  };

  for (final String category in byCategory.keys) {
    final List<FileReport> categoryFiles = byCategory[category]!;
    final double categorySize = categoryFiles.fold(
      0.0,
      (double sum, FileReport f) => sum + (f.sizeBytes / (1024 * 1024)),
    );
    final Map<String, dynamic> byCategoryReport = report['byCategory'] as Map<String, dynamic>;

    byCategoryReport[category] = <String, dynamic>{
      'count': categoryFiles.length,
      'totalSizeMb': categorySize.toStringAsFixed(2),
      'largestFiles': categoryFiles
          .take(5)
          .map(
            (FileReport f) => <String, dynamic>{
              'path': f.path,
              'sizeMb': (f.sizeBytes / (1024 * 1024)).toStringAsFixed(2),
            },
          )
          .toList(),
    };
  }

  final File reportFile = File('scripts/asset_analysis_report.json');
  reportFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('\nFull report saved to: scripts/asset_analysis_report.json');
}

class FileReport {
  FileReport(this.path, this.sizeBytes);
  final String path;
  final int sizeBytes;
}
