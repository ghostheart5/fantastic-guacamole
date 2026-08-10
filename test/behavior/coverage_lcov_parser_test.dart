import 'package:flutter_test/flutter_test.dart';

class _LcovSummary {
  const _LcovSummary({
    required this.linesFound,
    required this.linesHit,
    required this.fileCoverage,
  });

  final int linesFound;
  final int linesHit;
  final Map<String, ({int found, int hit, double percent})> fileCoverage;

  double get percent {
    if (linesFound == 0) {
      return 0;
    }
    return (linesHit / linesFound) * 100;
  }
}

class _LcovParser {
  static _LcovSummary parse(String lcov) {
    final List<String> lines = lcov.split('\n');
    String? currentFile;
    int currentFound = 0;
    int currentHit = 0;
    int totalFound = 0;
    int totalHit = 0;
    final Map<String, ({int found, int hit, double percent})> files =
        <String, ({int found, int hit, double percent})>{};

    void closeCurrent() {
      if (currentFile == null) {
        return;
      }
      final String file = currentFile;
      final int found = currentFound;
      final int hit = currentHit;
      final double percent = found == 0 ? 0 : (hit / found) * 100;
      files[file] = (found: found, hit: hit, percent: percent);
      totalFound += found;
      totalHit += hit;
    }

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.startsWith('SF:')) {
        closeCurrent();
        currentFile = line.substring(3);
        currentFound = 0;
        currentHit = 0;
      } else if (line.startsWith('LF:')) {
        currentFound = int.tryParse(line.substring(3)) ?? 0;
      } else if (line.startsWith('LH:')) {
        currentHit = int.tryParse(line.substring(3)) ?? 0;
      } else if (line == 'end_of_record') {
        closeCurrent();
        currentFile = null;
      }
    }

    closeCurrent();

    return _LcovSummary(
      linesFound: totalFound,
      linesHit: totalHit,
      fileCoverage: files,
    );
  }
}

void main() {
  group('LCOV parser behavior', () {
    test('parses SF LF LH records and computes totals', () {
      const String sample = '''
SF:lib/tutorial/tutorial_progress_store.dart
LF:20
LH:18
end_of_record
SF:lib/features/auth/application/auth_controller.dart
LF:50
LH:25
end_of_record
''';

      final _LcovSummary summary = _LcovParser.parse(sample);
      expect(summary.linesFound, 70);
      expect(summary.linesHit, 43);
      expect(summary.percent, closeTo(61.43, 0.01));
    });

    test('groups per-file coverage by lib feature folder', () {
      const String sample = '''
SF:lib/tutorial/tutorial_repository.dart
LF:10
LH:8
end_of_record
SF:lib/features/auth/application/auth_controller.dart
LF:40
LH:20
end_of_record
''';

      final _LcovSummary summary = _LcovParser.parse(sample);
      final tutorial =
          summary.fileCoverage['lib/tutorial/tutorial_repository.dart'];
      final auth = summary
          .fileCoverage['lib/features/auth/application/auth_controller.dart'];
      final tutorialCoverage = tutorial!;
      final authCoverage = auth!;

      expect(tutorial, isNotNull);
      expect(auth, isNotNull);
      expect(tutorialCoverage.percent, closeTo(80, 0.001));
      expect(authCoverage.percent, closeTo(50, 0.001));
    });
  });
}
