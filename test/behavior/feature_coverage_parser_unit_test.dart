import 'package:flutter_test/flutter_test.dart';

typedef _CoverageTuple = ({int found, int hit, double percent});

class _FeatureCoverageResult {
  const _FeatureCoverageResult({
    required this.globalPercent,
    required this.byFile,
    required this.byFeature,
  });

  final double globalPercent;
  final Map<String, _CoverageTuple> byFile;
  final Map<String, _CoverageTuple> byFeature;
}

class _FeatureCoverageParser {
  static _FeatureCoverageResult parse(String lcov) {
    final Map<String, _CoverageTuple> byFile = <String, _CoverageTuple>{};
    int totalFound = 0;
    int totalHit = 0;

    String? currentFile;
    int currentFound = 0;
    int currentHit = 0;

    void closeRecord() {
      final String? file = currentFile;
      if (file == null) {
        return;
      }
      final int found = currentFound;
      final int hit = currentHit;
      final double percent = found == 0 ? 0 : (hit / found) * 100;
      byFile[file] = (found: found, hit: hit, percent: percent);
      totalFound += found;
      totalHit += hit;
    }

    for (final String line in lcov.split('\n').map((String e) => e.trim())) {
      if (line.startsWith('SF:')) {
        closeRecord();
        currentFile = line.substring(3);
        currentFound = 0;
        currentHit = 0;
      } else if (line.startsWith('LF:')) {
        currentFound = int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LH:')) {
        currentHit = int.tryParse(line.substring(3)) ?? 0;
      } else if (line == 'end_of_record') {
        closeRecord();
        currentFile = null;
      }
    }

    closeRecord();

    final Map<String, ({int found, int hit})> accum =
        <String, ({int found, int hit})>{};
    byFile.forEach((String file, _CoverageTuple c) {
      final String feature = _featureKey(file);
      final current = accum[feature];
      accum[feature] = (
        found: (current?.found ?? 0) + c.found,
        hit: (current?.hit ?? 0) + c.hit,
      );
    });

    final Map<String, _CoverageTuple> byFeature = <String, _CoverageTuple>{};
    accum.forEach((String key, ({int found, int hit}) value) {
      byFeature[key] = (
        found: value.found,
        hit: value.hit,
        percent: value.found == 0 ? 0 : (value.hit / value.found) * 100,
      );
    });

    final double globalPercent = totalFound == 0
        ? 0
        : (totalHit / totalFound) * 100;

    return _FeatureCoverageResult(
      globalPercent: globalPercent,
      byFile: byFile,
      byFeature: byFeature,
    );
  }

  static String _featureKey(String sfPath) {
    if (sfPath.startsWith('lib/tutorial/')) {
      return 'lib/tutorial';
    }
    if (sfPath.startsWith('lib/features/')) {
      final List<String> parts = sfPath.split('/');
      if (parts.length >= 3) {
        return 'lib/features/${parts[2]}';
      }
    }
    if (sfPath.startsWith('lib/')) {
      final List<String> parts = sfPath.split('/');
      if (parts.length >= 2) {
        return 'lib/${parts[1]}';
      }
    }
    return 'other';
  }
}

void main() {
  group('Feature coverage parser', () {
    test('parses LCOV and computes feature and global percentages', () {
      const String sample = '''
SF:lib/tutorial/tutorial_progress_store.dart
LF:10
LH:8
end_of_record
SF:lib/features/auth/application/auth_controller.dart
LF:40
LH:20
end_of_record
SF:lib/features/tasks/ui/tasks_screen.dart
LF:0
LH:0
end_of_record
''';

      final _FeatureCoverageResult result = _FeatureCoverageParser.parse(
        sample,
      );

      expect(result.byFeature['lib/tutorial']!.percent, closeTo(80, 0.001));
      expect(
        result.byFeature['lib/features/auth']!.percent,
        closeTo(50, 0.001),
      );
      expect(result.byFeature['lib/features/tasks']!.percent, 0);
      expect(result.globalPercent, closeTo(56, 0.001));
    });

    test('sorts lowest coverage features first', () {
      const String sample = '''
SF:lib/tutorial/a.dart
LF:10
LH:10
end_of_record
SF:lib/features/auth/b.dart
LF:10
LH:3
end_of_record
SF:lib/features/tasks/c.dart
LF:10
LH:1
end_of_record
''';

      final _FeatureCoverageResult result = _FeatureCoverageParser.parse(
        sample,
      );
      final List<MapEntry<String, _CoverageTuple>> sorted =
          result.byFeature.entries.toList()
            ..sort((a, b) => a.value.percent.compareTo(b.value.percent));

      expect(sorted.first.key, 'lib/features/tasks');
      expect(sorted.first.value.percent, closeTo(10, 0.001));
    });
  });
}
