import 'dart:io';

import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retired standalone product surfaces stay removed', () {
    for (final String path in <String>[
      'lib/features/personal_alignment',
      'lib/features/plan/ui/plan_screen.dart',
      'lib/state/providers/personal_alignment_provider.dart',
      'lib/state/providers/core_values_provider.dart',
      'lib/state/providers/profile_values_provider.dart',
      'lib/state/providers/insights_provider.dart',
      'lib/state/controllers/insight_controller.dart',
      'lib/data/repositories/insight_repository.dart',
      'lib/engine/insights',
      'lib/ui/system/focus_start_overlay.dart',
    ]) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: 'Retired product path returned: $path',
      );
    }
    expect(
      File('lib/features/signals/ui/signal_screen.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/data/repositories/session_repository.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/domain/entities/session_entity.dart').existsSync(),
      isFalse,
    );
    expect(
      File('lib/domain/interfaces/i_session_repository.dart').existsSync(),
      isFalse,
    );
    expect(
      File('assets/animations/session_complete.json').existsSync(),
      isFalse,
    );
  });

  test(
    'Coach and Signal destinations stay removed while signals stay internal',
    () {
      final String routePaths = File(
        'lib/app/router/route_paths.dart',
      ).readAsStringSync();
      final String appRouter = File(
        'lib/app/router/app_router.dart',
      ).readAsStringSync();
      final String appFlow = File(
        'lib/state/controllers/app_flow_controller.dart',
      ).readAsStringSync();

      for (final String retiredDestination in <String>[
        '/coach',
        'legacyCoach',
        '/signals',
        'legacySignals',
      ]) {
        expect(routePaths, isNot(contains(retiredDestination)));
        expect(appRouter, isNot(contains(retiredDestination)));
        expect(appFlow, isNot(contains(retiredDestination)));
      }

      for (final String internalSignalPath in <String>[
        'lib/engine/signals/signal_engine.dart',
        'lib/state/providers/signals_provider.dart',
        'lib/state/services/signals_service.dart',
      ]) {
        expect(
          File(internalSignalPath).existsSync(),
          isTrue,
          reason:
              'Internal intelligence signal data was removed: $internalSignalPath',
        );
      }

      final List<String> productionCoachReferences = <String>[];
      for (final File file in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>().where(_isTextSurface)) {
        if (file.readAsStringSync().toLowerCase().contains('coach')) {
          productionCoachReferences.add(file.path.replaceAll('\\', '/'));
        }
      }
      expect(
        productionCoachReferences,
        isEmpty,
        reason:
            'Retired Coach terminology returned to production source: '
            '${productionCoachReferences.join(', ')}',
      );
    },
  );

  test('product UI and tutorial contain none of the forbidden names', () {
    final RegExp forbidden = RegExp(
      r'\b(?:personal[ _-]?alignment|planner[ _-]?analysis|journals?|focus|sessions?)\b',
      caseSensitive: false,
    );
    final List<String> violations = <String>[];
    for (final String root in <String>[
      'lib/features',
      'lib/app',
      'lib/tutorial',
      'assets',
    ]) {
      final Directory directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final File file
          in directory
              .listSync(recursive: true)
              .whereType<File>()
              .where(_isTextSurface)) {
        final RegExpMatch? match = forbidden.firstMatch(
          file.readAsStringSync(),
        );
        if (match != null) {
          final String normalizedPath = file.path.replaceAll('\\', '/');
          violations.add('$normalizedPath: ${match.group(0)}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('legacy navigation names resolve into current canon', () {
    expect(appViewFromName('coach'), isNull);
    expect(appViewFromName('smartCoach'), isNull);
    expect(appViewFromName('signal'), isNull);
  });

  test('legacy guidance preference memories retain their category', () {
    final MemoryEntity memory = MemoryEntity.fromJson(<String, dynamic>{
      'id': 'legacy-guidance',
      'text': 'Prefer concise planning guidance.',
      'date': DateTime.utc(2026).toIso8601String(),
      'category': 'coachingPreference',
    });

    expect(memory.category, MemoryCategory.planningGuidancePreference);
  });

  test('active product surfaces contain no retired terminology', () {
    final List<String> violations = <String>[];
    final List<FileSystemEntity> roots = <FileSystemEntity>[
      Directory('lib'),
      Directory('assets'),
      Directory('site'),
      Directory('web'),
    ];

    for (final FileSystemEntity root in roots) {
      final Iterable<File> files = root is Directory
          ? root
                .listSync(recursive: true)
                .whereType<File>()
                .where(_isTextSurface)
          : <File>[root as File];
      for (final File file in files) {
        final String path = file.path.replaceAll('\\', '/');
        String content = file.readAsStringSync();

        if (path.endsWith('lib/app/router/route_paths.dart') ||
            path.endsWith('lib/app/router/app_router.dart')) {
          content = content
              .replaceAll('legacyInsights', 'legacy_alias')
              .replaceAll('/insights', '/legacy-alias');
        }

        if (path.endsWith('app_flow_controller.dart')) {
          content = content.replaceAll('smartCoach', 'legacy_view');
        }

        final RegExpMatch? match = _retiredProductTerminology.firstMatch(
          _contentForTerminologyReview(path, content),
        );
        if (match != null) {
          violations.add('$path: ${match.group(0)}');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('every native shell presents the Axiomara product name', () {
    final Map<String, List<String>> requiredVisibleIdentity =
        <String, List<String>>{
          'android/app/src/main/AndroidManifest.xml': <String>[
            'android:label="Axiomara"',
          ],
          'ios/Runner/Info.plist': <String>[
            '<key>CFBundleDisplayName</key>',
            '<string>Axiomara</string>',
          ],
          'macos/Runner/Info.plist': <String>[
            '<key>CFBundleDisplayName</key>',
            '<string>Axiomara</string>',
          ],
          'windows/runner/main.cpp': <String>['window.Create(L"Axiomara"'],
          'windows/runner/Runner.rc': <String>[
            'VALUE "FileDescription", "Axiomara"',
            'VALUE "ProductName", "Axiomara"',
          ],
          'linux/runner/my_application.cc': <String>[
            'gtk_header_bar_set_title(header_bar, "Axiomara")',
            'gtk_window_set_title(window, "Axiomara")',
          ],
        };

    for (final MapEntry<String, List<String>> entry
        in requiredVisibleIdentity.entries) {
      final String content = File(entry.key).readAsStringSync();
      for (final String expected in entry.value) {
        expect(content, contains(expected), reason: entry.key);
      }
    }
  });

  test('visible app copy and bundled pages retire the old product vocabulary', () {
    final violations = <String>[];
    final dartRoots = [
      'lib/features',
      'lib/l10n',
      'lib/tutorial',
      'lib/ui/widgets',
    ];
    for (final root in dartRoots) {
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final path = file.path.replaceAll('\\', '/');
        for (final line in file.readAsLinesSync()) {
          if (line.trimLeft().startsWith(RegExp(r'(import|export|part|//)'))) {
            continue;
          }
          for (final match in _quotedCopy.allMatches(line)) {
            final copy = match.group(2)!;
            // These are compatibility keys, not labels. Preserve stored data,
            // old incoming navigation names, and exact memory provenance reads.
            if (_isInternalPlannerReceiptProvenance(path, line, copy) ||
                copy == 'nexus' ||
                copy.startsWith('nexus-') ||
                (path.endsWith('/si_console_screen.widgets.dart') &&
                    copy == 'si-console-welcome') ||
                copy.startsWith('assets/') ||
                copy.startsWith('https://') ||
                (path.endsWith('/nexus_copy.dart') &&
                    copy == 'Reconcile unscheduled work in Smart Planner.') ||
                (path.endsWith('/smart_planner_screen.dart') &&
                    copy ==
                        'User-entered in Smart Planner memory consent dialog.')) {
              continue;
            }
            if (_retiredVisibleProductNames.hasMatch(copy)) {
              violations.add('$path: $copy');
            }
          }
        }
      }
    }
    for (final root in ['assets/legal', 'web', 'site']) {
      for (final file in Directory(
        root,
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.html') && !file.path.endsWith('.txt')) {
          continue;
        }
        // Links retain the real legacy domains and package identifiers.
        final text = file.readAsStringSync().replaceAll(
          RegExp(r'https?://[^\s"<>]+'),
          '',
        );
        if (_retiredVisibleProductNames.hasMatch(text)) {
          violations.add(file.path);
        }
      }
    }
    // These are the current editable listing drafts, not historical Console,
    // graphics/data-safety receipts or wiki pages. This does not publish them.
    for (final path in <String>[
      'public-surface/google-play/store-listing-en-US.md',
      'public-surface/google-play/store-listing-es-419.md',
    ]) {
      final content = File(path).readAsStringSync();
      expect(
        content,
        contains('Local copy only; not saved, submitted or published'),
      );
      if (_retiredVisibleProductNames.hasMatch(
        _listingCopyForTerminologyReview(content),
      )) {
        violations.add(path);
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('retired copy check distinguishes brands from stable identifiers', () {
    for (final label in [
      'Nexus',
      'Decision OS',
      'The Human Decision OS',
      'Truth Ledger',
      'Trajectory Engine',
      'Smart Planner',
      'Planner V2',
      'Planificador V2',
      'SI Console',
      'Planificador Inteligente',
      'Consola SI',
      'Constructor de Realidad',
      'Nexus Core',
      'Future Branches',
      'Reality Builder',
      'Now Engine',
      'Control Center',
      'Control Centre',
      'Human Profile',
      'Capability Matrix',
      'Núcleo Nexus',
      'RAMAS FUTURAS',
      'Registro de Verdad',
      'Motor del Ahora',
      'Centro de Control',
      'Perfil Humano',
      'Matriz de Capacidades',
      'Motor de Trayectorias',
    ]) {
      expect(
        _retiredVisibleProductNames.hasMatch(label),
        isTrue,
        reason: label,
      );
    }
    for (final identifier in [
      'nexusTimeBlocksProvider',
      'ChronoSparkLocalizations',
      'TemporalGlassSurface',
      'trajectoryEngine',
      'futureBranches',
      'truthLedger',
      'humanProfile',
      'capabilityMatrix',
      'realityBuilder',
      'SI Chat',
      'predictions',
      'future outcomes',
      'goals, tasks, and habits',
    ]) {
      expect(
        _retiredVisibleProductNames.hasMatch(identifier),
        isFalse,
        reason: identifier,
      );
    }
  });

  test('listing guard excludes only the stable package identifier', () {
    expect(
      _retiredVisibleProductNames.hasMatch(
        _listingCopyForTerminologyReview(
          'Package com.ghostheart5.chronospark is unchanged.',
        ),
      ),
      isFalse,
    );
    for (final copy in [
      'Package com.ghostheart5.chronospark is unchanged. Nexus',
      'Package com.other.chronospark is unchanged.',
      'Future Branches',
      'RAMAS FUTURAS',
    ]) {
      expect(
        _retiredVisibleProductNames.hasMatch(
          _listingCopyForTerminologyReview(copy),
        ),
        isTrue,
        reason: copy,
      );
    }
  });

  test(
    'receipt provenance exception cannot hide displayed Planner V2 copy',
    () {
      const path = 'lib/features/home/ui/smart_planner_screen.dart';
      const provenance = 'Matched operating receipt shown in Planner V2.';
      expect(
        _isInternalPlannerReceiptProvenance(
          path,
          "detail: '$provenance',",
          provenance,
        ),
        isTrue,
      );
      for (final line in [
        "Text('$provenance')",
        "label: '$provenance',",
        "detail: 'Planner V2',",
      ]) {
        expect(
          _isInternalPlannerReceiptProvenance(path, line, provenance),
          isFalse,
        );
      }
      expect(
        _isInternalPlannerReceiptProvenance(
          'lib/features/settings/ui/settings_screen.dart',
          "detail: '$provenance',",
          provenance,
        ),
        isFalse,
      );
    },
  );

  test('legal citation exception cannot hide retired product wording', () {
    const String noticePath =
        'assets/legal/licenses/material-icons-sdk-notice.txt';
    const String citation = 'Directive 96/9/EC';
    final String notice = File(noticePath).readAsStringSync();
    expect(notice, contains(citation));
    expect(
      _retiredProductTerminology.hasMatch(
        _contentForTerminologyReview(noticePath, notice),
      ),
      isFalse,
    );
    for (final String content in <String>[
      '$notice\nDirective',
      notice.replaceAll(citation, 'Directive 96/9/EE'),
    ]) {
      expect(
        _retiredProductTerminology.hasMatch(
          _contentForTerminologyReview(noticePath, content),
        ),
        isTrue,
      );
    }
    expect(
      _retiredProductTerminology.hasMatch(
        _contentForTerminologyReview(
          'assets/legal/privacy_policy.html',
          citation,
        ),
      ),
      isTrue,
    );
  });
}

final RegExp _retiredProductTerminology = RegExp(
  r'\b(?:smart[ _-]?coach|chrono[ _-]?creator|chrono[ _-]?logs|soul[ _-]?maps?|missions?|military|commands?|briefings?|command[ _-]?cent(?:er|re)|control[ _-]?room|tactical|directive|ops|intel|session[ _-]?(?:score|scoring|complete)|last[ _-]?session)\b',
  caseSensitive: false,
);

String _contentForTerminologyReview(String path, String content) {
  // Preserve the verbatim third-party license (hash-checked by the license
  // contract) while recognizing this exact legal citation, not a product name.
  if (path == 'assets/legal/licenses/material-icons-sdk-notice.txt') {
    return content.replaceAll('Directive 96/9/EC', 'EU database-rights law');
  }
  return content;
}

bool _isTextSurface(File file) {
  const Set<String> extensions = <String>{
    '.dart',
    '.html',
    '.json',
    '.md',
    '.txt',
    '.yaml',
    '.yml',
  };
  final String path = file.path.toLowerCase();
  return extensions.any(path.endsWith);
}

// Review rendered strings rather than banning route/type/storage identifiers.
final RegExp _retiredVisibleProductNames = RegExp(
  r'\b(?:nexus(?:[ -]core)?|chrono\s?spark|(?:human[ -])?decision[ -]os|truth[ -]ledger|trajectory[ -]engine|future[ -]branches|reality[ -]builder|now[ -]engine|control[ -]cent(?:er|re)|human[ -]profile|capability[ -]matrix|smart[ -]planner|planner v2|planificador v2|si[ -]console|planificador inteligente|consola si|motor de trayectorias?|constructor de realidad|núcleo nexus|ramas futuras|registro de (?:la )?verdad|motor (?:del? )?ahora|centro de control|perfil humano|matriz de capacidades)\b',
  caseSensitive: false,
);
final RegExp _quotedCopy = RegExp(r"""(['"])((?:\\.|(?!\1).)*)\1""");

// Historical shown-event provenance is serialized/exported, not a display
// label or lookup key. Keep the exception pinned to its exact producer field.
bool _isInternalPlannerReceiptProvenance(
  String path,
  String line,
  String copy,
) =>
    path == 'lib/features/home/ui/smart_planner_screen.dart' &&
    line.trim() ==
        "detail: 'Matched operating receipt shown in Planner V2.'," &&
    copy == 'Matched operating receipt shown in Planner V2.';

String _listingCopyForTerminologyReview(String content) =>
    content.replaceAll('com.ghostheart5.chronospark', '');
