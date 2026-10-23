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
    final dartSources = [
      'lib/features',
      'lib/l10n',
      'lib/tutorial',
      'lib/ui/widgets',
      'lib/state/controllers/smart_planner_query_controller.support.dart',
      'lib/state/controllers/smart_planner_query_controller.dart',
      'lib/state/controllers/smart_planner_query_controller.person_context.dart',
      'lib/engine/si/si_v2_engine.dart',
      'lib/domain/entities/habit_entity.dart',
    ];
    for (final source in dartSources) {
      final files = source.endsWith('.dart')
          ? [File(source)]
          : Directory(source).listSync(recursive: true).whereType<File>();
      for (final file in files) {
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
                _isAuditedPlannerContractMetadata(path, line, copy) ||
                _isAuditedProtocolIdentifier(path, line, copy) ||
                _isLegacyHabitLookupInput(path, line, copy) ||
                copy == 'nexus' ||
                copy.startsWith('nexus-') ||
                (path.endsWith('/si_console_screen.widgets.dart') &&
                    copy == 'si-console-welcome') ||
                copy.startsWith('assets/') ||
                copy.startsWith('https://') ||
                (path.endsWith('/nexus_copy.dart') &&
                    copy == 'Reconcile unscheduled work in Smart Planner.')) {
              continue;
            }
            if (_retiredVisibleProductNames.hasMatch(copy) ||
                _hasRetiredGeneratedContextCopy(path, copy)) {
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

  test('protocol allowances are exact fields, not display copy', () {
    const contextPath =
        'lib/state/controllers/smart_planner_query_controller.person_context.dart';
    const contract = 'smart-planner-person-context-behavior-v1';
    expect(
      _isAuditedProtocolIdentifier(
        contextPath,
        "'contract': '$contract',",
        contract,
      ),
      isTrue,
    );
    const siPath = 'lib/engine/si/si_v2_engine.dart';
    const uris = <String>[
      r'chronospark://${source.name}',
      r'chronospark://tasks/${item.id}',
      r'chronospark://goals/${item.id}',
      r'chronospark://milestones/${item.id}',
      r'chronospark://timeline/${item.id}',
      r'chronospark://person-context/${item.id}',
    ];
    for (final uri in uris) {
      expect(_isAuditedProtocolIdentifier(siPath, "uri: '$uri',", uri), isTrue);
    }
    for (final entry in <String, String>{
      contract: contextPath,
      for (final uri in uris) uri: siPath,
    }.entries) {
      expect(_retiredVisibleProductNames.hasMatch(entry.key), isTrue);
      for (final statement in <String>[
        "return '${entry.key}';",
        "label: '${entry.key}',",
        "Text('${entry.key}')",
      ]) {
        expect(
          _isAuditedProtocolIdentifier(entry.value, statement, entry.key),
          isFalse,
        );
      }
      expect(
        _isAuditedProtocolIdentifier(
          'lib/features/settings/ui/settings_screen.dart',
          "uri: '${entry.key}',",
          entry.key,
        ),
        isFalse,
      );
    }
    expect(
      _isAuditedProtocolIdentifier(
        siPath,
        "uri: 'chronospark://unknown',",
        'chronospark://unknown',
      ),
      isFalse,
    );
  });

  test(
    'generated context guard covers audited producers without banning keys',
    () {
      for (final path in [
        'lib/state/controllers/smart_planner_query_controller.dart',
        'lib/state/controllers/smart_planner_query_controller.person_context.dart',
        'lib/state/controllers/smart_planner_query_controller.support.dart',
        'lib/engine/si/si_v2_engine.dart',
      ]) {
        expect(
          _hasRetiredGeneratedContextCopy(
            path,
            'Person Context is unavailable.',
          ),
          isTrue,
        );
        expect(
          _hasRetiredGeneratedContextCopy(
            path,
            'Contexto Personal no disponible.',
          ),
          isTrue,
        );
        expect(
          _hasRetiredGeneratedContextCopy(path, 'personContextStatus'),
          isFalse,
        );
        expect(
          _hasRetiredGeneratedContextCopy(path, 'person-context:priority'),
          isFalse,
        );
      }
      const path = 'lib/state/controllers/smart_planner_query_controller.dart';
      const text = 'Origin: deterministic on-device Planner V2.';
      expect(
        _isAuditedPlannerContractMetadata(path, ": '$text',", text),
        isTrue,
      );
      expect(
        _isAuditedPlannerContractMetadata(path, "return '$text';", text),
        isFalse,
      );
      expect(
        _isAuditedPlannerContractMetadata(
          'lib/features/home/ui/example.dart',
          ": '$text',",
          text,
        ),
        isFalse,
      );
    },
  );

  test('retired copy check distinguishes brands from stable identifiers', () {
    for (final label in [
      'Nexus',
      'Decision OS',
      'The Human Decision OS',
      'Truth Ledger',
      'Trajectory Engine',
      'Smart Planner',
      'Planner V2',
      'Review on Home',
      'Daily Rhythm',
      'Daily Rhythms',
      'Ritmo diario',
      'Ritmos diarios',
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
      'Deep Intelligence',
      'Inteligencia profunda',
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
      'homework',
      'home',
      'DailyRhythm',
      'daily-rhythms',
      'dailyRhythmId',
    ]) {
      expect(
        _retiredVisibleProductNames.hasMatch(identifier),
        isFalse,
        reason: identifier,
      );
    }
  });

  test('habit lookup allowances cannot hide retired display output', () {
    const creatorPath = 'lib/l10n/creator_copy.dart';
    const settingsPath =
        'lib/features/settings/ui/settings_screen.planning_sections.dart';
    const safeInputs = <(String, String, String)>[
      (
        creatorPath,
        "for (final entity in ['task', 'goal', 'daily rhythm', 'note']) {",
        'daily rhythm',
      ),
      (
        creatorPath,
        "final noun = entity == 'daily rhythm' ? 'habit' : entity;",
        'daily rhythm',
      ),
      (
        creatorPath,
        "final english = name == 'habit' ? 'daily rhythm' : name;",
        'daily rhythm',
      ),
      (
        settingsPath,
        "if (value == 'daily rhythm occurrence') {",
        'daily rhythm occurrence',
      ),
    ];
    for (final entry in safeInputs) {
      expect(_isLegacyHabitLookupInput(entry.$1, entry.$2, entry.$3), isTrue);
      expect(
        _isLegacyHabitLookupInput('lib/unrelated.dart', entry.$2, entry.$3),
        isFalse,
      );
    }
    for (final line in [
      "return 'Daily Rhythm';",
      "final noun = entity == 'daily rhythm' ? 'Daily Rhythm' : entity;",
      "'daily rhythm': 'Daily Rhythm',",
      "if (value == 'daily rhythm occurrence') return 'Daily Rhythm';",
    ]) {
      for (final path in [creatorPath, settingsPath]) {
        final violations = _quotedCopy
            .allMatches(line)
            .map((match) => match.group(2)!)
            .where(
              (copy) =>
                  _retiredVisibleProductNames.hasMatch(copy) &&
                  !_isLegacyHabitLookupInput(path, line, copy),
            );
        expect(violations, contains('Daily Rhythm'), reason: '$path: $line');
      }
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
  r'\b(?:nexus(?:[ -]core)?|chrono\s?spark|(?:human[ -])?decision[ -]os|truth[ -]ledger|trajectory[ -]engine|future[ -]branches|reality[ -]builder|now[ -]engine|control[ -]cent(?:er|re)|human[ -]profile|capability[ -]matrix|smart[ -]planner|planner v2|review on home|daily rhythms?|ritmos? diarios?|planificador v2|si[ -]console|deep[ -]intelligence|inteligencia profunda|planificador inteligente|consola si|motor de trayectorias?|constructor de realidad|núcleo nexus|ramas futuras|registro de (?:la )?verdad|motor (?:del? )?ahora|centro de control|perfil humano|matriz de capacidades)\b',
  caseSensitive: false,
);
final RegExp _quotedCopy = RegExp(r"""(['"])((?:\\.|(?!\1).)*)\1""");

// Closed legacy input selectors used by verified display mappings. Their
// exact statements are allowed; returned text and unknown statements are not.
bool _isLegacyHabitLookupInput(String path, String line, String copy) {
  final statement = line.trim();
  if (path == 'lib/l10n/creator_copy.dart' && copy == 'daily rhythm') {
    return const <String>{
      "for (final entity in ['task', 'goal', 'daily rhythm', 'note']) {",
      "final noun = entity == 'daily rhythm' ? 'habit' : entity;",
      "final english = name == 'habit' ? 'daily rhythm' : name;",
    }.contains(statement);
  }
  return path ==
          'lib/features/settings/ui/settings_screen.planning_sections.dart' &&
      copy == 'daily rhythm occurrence' &&
      statement == "if (value == 'daily rhythm occurrence') {";
}

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

// Exact diagnostics and contract-origin evidence, not rendered guidance fields.
bool _isAuditedPlannerContractMetadata(String path, String line, String copy) {
  if (path != 'lib/state/controllers/smart_planner_query_controller.dart') {
    return false;
  }
  return const <String, String>{
        "Smart Planner response failed its safety boundary.":
            "throw StateError('Smart Planner response failed its safety boundary.');",
        "Smart Planner account scope changed while loading evidence.":
            "'Smart Planner account scope changed while loading evidence.',",
        "Smart Planner must show the dedicated crisis support route.":
            "'Smart Planner must show the dedicated crisis support route.',",
        "Origen: Planner V2 determinista en el dispositivo.":
            "? 'Origen: Planner V2 determinista en el dispositivo.'",
        "Origin: deterministic on-device Planner V2.":
            ": 'Origin: deterministic on-device Planner V2.',",
      }[copy] ==
      line.trim();
}

bool _hasRetiredGeneratedContextCopy(String path, String copy) =>
    const <String>{
      'lib/state/controllers/smart_planner_query_controller.dart',
      'lib/state/controllers/smart_planner_query_controller.person_context.dart',
      'lib/state/controllers/smart_planner_query_controller.support.dart',
      'lib/engine/si/si_v2_engine.dart',
    }.contains(path) &&
    RegExp(
      r'\b(?:person context|contexto personal)\b',
      caseSensitive: false,
    ).hasMatch(copy);

// Stable digest contract and evidence-link protocol fields, never labels.
// Each allowance requires the audited path, complete statement and literal.
bool _isAuditedProtocolIdentifier(String path, String line, String copy) {
  if (path ==
      'lib/state/controllers/smart_planner_query_controller.person_context.dart') {
    return copy == 'smart-planner-person-context-behavior-v1' &&
        line.trim() ==
            "'contract': 'smart-planner-person-context-behavior-v1',";
  }
  return path == 'lib/engine/si/si_v2_engine.dart' &&
      const <String>{
        r'chronospark://${source.name}',
        r'chronospark://tasks/${item.id}',
        r'chronospark://goals/${item.id}',
        r'chronospark://milestones/${item.id}',
        r'chronospark://timeline/${item.id}',
        r'chronospark://person-context/${item.id}',
      }.contains(copy) &&
      line.trim() == "uri: '$copy',";
}
