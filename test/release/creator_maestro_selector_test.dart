import 'dart:io';

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/creator_copy.dart';
import 'package:fantastic_guacamole/l10n/nexus_copy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  List<dynamic> commands(String path) =>
      loadYamlDocuments(File(path).readAsStringSync())[1].contents as YamlList;

  Iterable<MapEntry<dynamic, dynamic>> entries(dynamic value) sync* {
    if (value is Map) {
      for (final entry in value.entries) {
        yield entry;
        yield* entries(entry.value);
      }
    } else if (value is Iterable) {
      for (final child in value) {
        yield* entries(child);
      }
    }
  }

  Iterable<String> visibleSelectorValues(dynamic value) sync* {
    if (value is Map) {
      for (final entry in value.entries) {
        // Absence assertions intentionally verify retired labels stay absent.
        if (entry.key == 'assertNotVisible') continue;
        if (const {
              'TARGET',
              'tapOn',
              'assertVisible',
              'text',
              'visible',
              'notVisible',
            }.contains(entry.key) &&
            entry.value is String) {
          yield entry.value as String;
        }
        yield* visibleSelectorValues(entry.value);
      }
    } else if (value is Iterable) {
      for (final child in value) {
        yield* visibleSelectorValues(child);
      }
    }
  }

  final retiredDestination = RegExp(
    r'\b(?:Nexus(?: Core)?|Control Center|Reality Builder|Truth Ledger|Now Engine|Smart Planner|SI Console|Trajectory Engine|Future Branches|Human Profile|Capability Matrix)\b',
    caseSensitive: false,
  );

  final staleUppercaseHeading = RegExp(r'\bSETTINGS\b');

  test(
    'runtime YAML destinations and visible selectors use current labels',
    () {
      final files = Directory('.maestro')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.yaml'));
      for (final file in files) {
        for (final document in loadYamlDocuments(file.readAsStringSync())) {
          for (final selector in visibleSelectorValues(document.contents)) {
            expect(
              retiredDestination.hasMatch(selector) ||
                  staleUppercaseHeading.hasMatch(selector),
              isFalse,
              reason: '${file.path} has a retired visible selector: $selector',
            );
          }
        }
      }
    },
  );

  test('selector guard ignores filenames and preserved typed text only', () {
    final fixture = loadYaml("""
# Nexus remains an internal historical name.
- runFlow:
    file: ../subflows/open-from-nexus.yaml
    env:
      TARGET: Settings
- inputText: My note says Nexus and Control Center
- assertNotVisible:
    text: Control Center
- tapOn:
    text: Control Center
- assertVisible: Truth Ledger
- assertVisible: SETTINGS
""");
    expect(
      visibleSelectorValues(fixture).where(
        (value) =>
            retiredDestination.hasMatch(value) ||
            staleUppercaseHeading.hasMatch(value),
      ),
      ['Control Center', 'Truth Ledger', 'SETTINGS'],
    );
  });

  test(
    'readiness matches standalone or exact merged Settings and Today nodes',
    () {
      const mergedSettings =
          'Make the app work for you\nSettings\nChange your preferences, review shared information, or manage your account.';
      for (final path in [
        '.maestro/qa/10-subscription-containment.yaml',
        '.maestro/flows/priority8-learned-lifecycle-readback.yaml',
      ]) {
        final selectors = entries(commands(path))
            .where(
              (entry) => const {
                'visible',
                'notVisible',
                'assertVisible',
              }.contains(entry.key),
            )
            .map((entry) => entry.value)
            .whereType<String>()
            .where((value) => value.contains('Settings'));
        expect(selectors, isNotEmpty);
        for (final selector in selectors) {
          final matcher = RegExp(
            selector.replaceFirst('(?s)', ''),
            dotAll: true,
          );
          expect(matcher.hasMatch('Settings'), isTrue);
          expect(matcher.hasMatch(mergedSettings), isTrue);
          expect(
            matcher.hasMatch('Unrelated\nSettings\nUnrelated subtitle'),
            isFalse,
          );
          expect(matcher.hasMatch('$mergedSettings extra'), isFalse);
          expect(matcher.hasMatch('Unrelated\n$mergedSettings'), isFalse);
          expect(matcher.hasMatch('SETTINGS'), isFalse);
          expect(matcher.hasMatch('Old Settings panel'), isFalse);
          expect(matcher.hasMatch('Settings\nUnrelated subtitle'), isFalse);
          if (selector.contains('Today')) {
            expect(matcher.hasMatch('Today'), isTrue);
            expect(matcher.hasMatch('Today\nToday'), isFalse);
          }
        }
      }
    },
  );

  test(
    'all scheduled-task journeys reveal optional fields before date selection',
    () {
      for (final path in [
        '.maestro/flows/05-creator.yaml',
        '.maestro/subflows/create-scheduled-task.yaml',
        '.maestro/flows/priority8-learned-lifecycle.yaml',
      ]) {
        var optionsRevealed = false;
        var scheduleCount = 0;
        for (final command in commands(
          path,
        ).whereType<Map<dynamic, dynamic>>()) {
          final tap = command['tapOn'];
          if (tap is String && tap.contains('Task options')) {
            optionsRevealed = true;
          }
          final scroll = command['scrollUntilVisible'];
          if (scroll is Map &&
              scroll['element'] is Map &&
              (scroll['element'] as Map)['text'] is String &&
              ((scroll['element'] as Map)['text'] as String).contains(
                'Schedule date and time',
              )) {
            expect(optionsRevealed, isTrue, reason: path);
          }
          if (tap is String && tap.contains('Schedule date and time')) {
            final matcher = RegExp(tap);
            expect(matcher.hasMatch('Schedule date and time...'), isTrue);
            expect(matcher.hasMatch('Clear Schedule date and time'), isFalse);
            expect(optionsRevealed, isTrue, reason: path);
            optionsRevealed = false;
            scheduleCount++;
          }
        }
        expect(scheduleCount, path.contains('learned-lifecycle') ? 2 : 1);
      }
    },
  );

  test('planning journeys dispatch the current suggestion action', () {
    final label = const PlannerRoutineCopy(
      false,
    ).guidanceButton(refresh: false);
    for (final path in [
      '.maestro/flows/04-smart-planner.yaml',
      '.maestro/flows/priority8-learned-lifecycle.yaml',
    ]) {
      final flow = commands(path);
      final tap = flow.indexWhere(
        (command) => command is Map && command['tapOn'] == label,
      );
      expect(tap, greaterThan(0), reason: path);
      expect(flow[tap - 1], {
        'scrollUntilVisible': {
          'element': {'text': label},
          'direction': 'DOWN',
          'timeout': 15000,
        },
      });
      expect(flow[tap + 1], {
        'extendedWaitUntil': {
          'visible': '(?s)Planning guidance ready.*',
          'timeout': 30000,
        },
      });
      expect(visibleSelectorValues(flow), isNot(contains('GET GUIDANCE')));
    }
  });

  test('manual saves and Planner review preserve distinct consent paths', () {
    const copy = CreatorCopy(false);
    final manual = commands('.maestro/subflows/create-scheduled-task.yaml');
    final manualTaps = entries(manual)
        .where((entry) => entry.key == 'tapOn')
        .map((entry) => entry.value)
        .whereType<String>();
    expect(manualTaps, contains('^${copy.createAction('task')}\$'));
    expect(manualTaps, isNot(contains('^${copy.reviewChanges}\$')));
    final lifecycle = commands(
      '.maestro/flows/priority8-learned-lifecycle.yaml',
    );
    final scalarEntries = entries(lifecycle)
        .where((entry) => entry.value is String)
        .map((entry) => entry.value as String)
        .toList();
    expect(scalarEntries, contains('^${copy.draftPreview}\$'));
    expect(scalarEntries, contains('^${copy.reviewChanges}\$'));
    expect(scalarEntries, contains('^Ready to save\\?\$'));
    expect(scalarEntries, contains('Task: Fold one shirt'));
    for (final proof in [
      'Use this plan',
      'Task Completed',
      const NexusCopy(false).learningChanged,
      'stopApp',
      'RECENT RAW OBSERVATIONS',
    ]) {
      expect(
        File(
          '.maestro/flows/priority8-learned-lifecycle.yaml',
        ).readAsStringSync(),
        contains(proof),
      );
    }
  });

  test(
    'learned journey opens the real detailed review before learning proof',
    () {
      final flow = commands('.maestro/flows/priority8-learned-lifecycle.yaml');
      const copy = NexusCopy(false);
      final entry = flow.indexWhere(
        (command) =>
            command is Map && command['tapOn'] == r'^Review my day in detail$',
      );
      final learning = flow.indexWhere(
        (command) =>
            command is Map &&
            command['extendedWaitUntil'] is Map &&
            (command['extendedWaitUntil'] as Map)['visible'] ==
                '^${copy.learningChanged}\$',
      );
      final completed = flow.indexWhere(
        (command) =>
            command is Map &&
            command['assertVisible'] == '.*completed outcome.*',
      );
      final restart = flow.indexWhere(
        (command) =>
            command == 'stopApp' ||
            (command is Map && command.containsKey('stopApp')),
      );
      expect(entry, greaterThanOrEqualTo(0));
      expect(learning, greaterThan(entry));
      expect(completed, greaterThan(learning));
      expect(restart, greaterThan(completed));
      final todaySource = File(
        'lib/features/home/ui/today_screen.dart',
      ).readAsStringSync();
      expect(todaySource, contains("'Review my day in detail'"));
      expect(todaySource, contains('NexusScreen(showDetails: true)'));
      final raw = File(
        '.maestro/flows/priority8-learned-lifecycle.yaml',
      ).readAsStringSync();
      expect(raw, isNot(contains('WHAT LEARNING CHANGED')));
      // Each pushed Schedule returns to its Creator receipt, then uses the
      // explicit Creator header. No blind direct Schedule-to-Today assumption.
      var returnChains = 0;
      for (var index = 0; index + 3 < flow.length; index++) {
        final back = flow[index];
        final wait = flow[index + 1];
        final tap = flow[index + 3];
        if ((back == 'back' || (back is Map && back.containsKey('back'))) &&
            wait is Map &&
            wait['extendedWaitUntil'] is Map &&
            (wait['extendedWaitUntil'] as Map)['visible'] ==
                r'^Add something$' &&
            tap is Map &&
            tap['tapOn'] == r'^Back to Today$') {
          returnChains++;
        }
      }
      expect(returnChains, 2);
      for (final path in [
        '.maestro/flows/priority8-learned-lifecycle.yaml',
        '.maestro/flows/priority8-learned-lifecycle-readback.yaml',
      ]) {
        final selectors = entries(commands(path)).map((entry) => entry.value);
        expect(selectors, contains('RECENT RAW OBSERVATIONS'));
        expect(
          selectors,
          contains(
            '(?s).*Task Lifecycle.*completed.*Completed the task.*helped.*',
          ),
        );
      }
    },
  );

  test(
    'shared setup exits prefer the top action and cover a lower-only viewport',
    () {
      for (final name in ['skip-onboarding', 'sign-in', 'sign-in-qa']) {
        final flow = commands('.maestro/subflows/$name.yaml');
        for (final visible in <Set<String>>[
          {'Go to Today', 'SKIP FOR NOW'},
          {'SKIP FOR NOW'},
          {'Today'},
        ]) {
          final taps = <String>[];
          bool matches(dynamic pattern) =>
              pattern is String &&
              visible.any((label) => RegExp(pattern).hasMatch(label));
          void walk(dynamic value) {
            if (value is! Iterable) return;
            for (final command in value.whereType<Map<dynamic, dynamic>>()) {
              final run = command['runFlow'];
              if (run is Map) {
                final condition = run['when'];
                if (condition is Map &&
                    ((condition.containsKey('visible') &&
                            !matches(condition['visible'])) ||
                        (condition.containsKey('notVisible') &&
                            matches(condition['notVisible'])))) {
                  continue;
                }
                walk(run['commands']);
              }
              final tap = command['tapOn'];
              if (tap is String &&
                  ['Go to Today', 'SKIP FOR NOW'].contains(tap)) {
                taps.add(tap);
              }
            }
          }

          // Retain the same viewport after a tap: the fallback must not mask an
          // unsuccessful top tap by invoking the other completion action too.
          walk(flow);
          final expected = visible.contains('Go to Today')
              ? ['Go to Today']
              : visible.contains('SKIP FOR NOW')
              ? ['SKIP FOR NOW']
              : <String>[];
          expect(
            taps,
            expected,
            reason: '$name must handle viewport $visible exactly once',
          );
        }
      }
    },
  );

  test(
    'manual creator smoke uses the actual save actions and retains durable readback',
    () {
      final flow = commands('.maestro/flows/05-creator.yaml');
      final taps = entries(flow)
          .where((entry) => entry.key == 'tapOn')
          .map((entry) => entry.value)
          .whereType<String>();
      const copy = CreatorCopy(false);
      for (final kind in ['task', 'habit', 'goal']) {
        expect(taps, contains('^${copy.createAction(kind)}\$'));
      }
      final raw = File('.maestro/flows/05-creator.yaml').readAsStringSync();
      // Keep the behaviors previously guarded by the longer two-step flow.
      for (final proof in [
        'SCHEDULED',
        'Maestro smoke task',
        'Pause',
        'Resume',
        'Mark target completed',
        'Completed this day',
        'Skip this day',
        'stopApp',
        'No linked goal',
        'Maestro preserved goal',
      ]) {
        expect(
          raw,
          contains(proof),
          reason: 'Preserve the $proof runtime guard.',
        );
      }
      final receipt = File(
        '.maestro/subflows/verify-creator-saved-receipt.yaml',
      ).readAsStringSync();
      expect(receipt, contains('1 change saved'));
      expect(receipt, contains(r'${SAVED_ITEM}'));
      expect(receipt, contains(copy.undo));
    },
  );

  test('account readback leaves Schedule through Creator before Settings', () {
    const helperPath = '.maestro/subflows/return-from-schedule-to-today.yaml';
    final helper = commands(helperPath);
    expect(helper, hasLength(5));
    expect(helper[0], 'back');
    expect(helper[1], {
      'extendedWaitUntil': {'visible': r'^Add something$', 'timeout': 10000},
    });
    expect(helper[2], {
      'scrollUntilVisible': {
        'element': {'text': r'^Back to Today$'},
        'direction': 'UP',
        'visibilityPercentage': 100,
        'centerElement': false,
        'timeout': 10000,
      },
    });
    expect(helper[3], {'tapOn': r'^Back to Today$'});
    expect(helper[4], {
      'extendedWaitUntil': {'visible': r'^Today$', 'timeout': 10000},
    });
    // The complete helper contains navigation only: no launch/clear/logout,
    // record writes, conditional bypass, or retry can erase the saved sentinel.
    final qa = commands('.maestro/qa/priority8-account-isolation.yaml');
    final account = commands('.maestro/flows/priority8-account-isolation.yaml');
    const returnCall = '../subflows/return-from-schedule-to-today.yaml';
    bool isReturn(dynamic value) =>
        value is Map && value['runFlow'] == returnCall;
    final localReturn = qa.indexWhere(isReturn);
    expect(localReturn, greaterThan(0));
    expect(qa.where(isReturn), hasLength(1));
    expect(qa[localReturn - 1], {
      'assertVisible': '(?s).*P8 Local Profile Sentinel.*',
    });
    expect(qa[localReturn + 1], {
      'runFlow': {
        'file': '../subflows/open-from-nexus.yaml',
        'env': {'TARGET': 'Settings'},
      },
    });
    final accountReturns = <int>[
      for (var i = 0; i < account.length; i++)
        if (isReturn(account[i])) i,
    ];
    expect(accountReturns, hasLength(2));
    expect(account[accountReturns[0] - 1], {
      'assertVisible': '(?s).*P8 Account A Sentinel.*',
    });
    expect(account[accountReturns[1] - 2], {
      'assertVisible': '(?s).*P8 Account B Sentinel.*',
    });
    expect(account[accountReturns[1] - 1], {
      'assertNotVisible': '(?s).*P8 Account A Sentinel.*',
    });
    for (final index in accountReturns) {
      expect(account[index + 1], {
        'runFlow': '../subflows/exit-tester-account.yaml',
      });
    }
    for (final path in [
      '.maestro/qa/priority8-account-isolation.yaml',
      '.maestro/flows/priority8-account-isolation.yaml',
    ]) {
      for (final entry in entries(commands(path))) {
        if (entry.key != 'runFlow') continue;
        final value = entry.value;
        final relative = value is String
            ? value
            : value is Map
            ? value['file'] as String?
            : null;
        if (relative == null) continue;
        expect(
          File.fromUri(File(path).absolute.uri.resolve(relative)).existsSync(),
          isTrue,
          reason: 'Missing dependency $path -> $relative',
        );
      }
    }
    final savedTask = commands('.maestro/subflows/create-scheduled-task.yaml');
    expect(savedTask.last, {
      'extendedWaitUntil': {
        'visible':
            r'(?s).*${TASK_TITLE}.*(?:Task is scheduled for a planned work time|Scheduled work time has passed. The task remains open; no deadline was missed).*',
        'timeout': 20000,
      },
    });
    expect(
      entries(savedTask).any(
        (entry) =>
            entry.key == 'runFlow' &&
            entry.value is Map &&
            (entry.value as Map<dynamic, dynamic>)['file'] ==
                'verify-creator-saved-receipt.yaml',
      ),
      isTrue,
    );
    expect(qa, contains('stopApp'));
    expect(qa, contains('launchApp'));
    expect(account.last, {'assertNotVisible': '(?s).*P8 Account B Sentinel.*'});
  });

  test('all five smoke flows retain resolvable source-bound dependencies', () {
    final visited = <String>{};
    void visit(String path) {
      final file = File(path).absolute;
      if (!visited.add(file.path)) return;
      for (final entry in entries(commands(file.path))) {
        if (entry.key != 'runFlow') continue;
        final relative = entry.value is String
            ? entry.value as String
            : entry.value is Map
            ? (entry.value as Map)['file'] as String?
            : null;
        if (relative == null) continue;
        final dependency = File.fromUri(file.uri.resolve(relative));
        expect(
          dependency.existsSync(),
          isTrue,
          reason: 'Missing flow dependency $relative',
        );
        visit(dependency.path);
      }
    }

    for (final name in [
      '04-smart-planner',
      '05-creator',
      '06-si-console',
      '07-timeline',
      '08-progression',
    ]) {
      visit('.maestro/flows/$name.yaml');
    }
    final signIn = File('.maestro/subflows/sign-in.yaml').readAsStringSync();
    expect(signIn, contains('visible: "Today"'));
    expect(signIn, contains('assertVisible: "Add a goal, task or habit"'));
    expect(signIn, isNot(contains('NEXUS')));
  });

  test(
    'creator selectors accept the observed native date and expansion labels',
    () {
      final flow = commands('.maestro/flows/05-creator.yaml');
      final taps = entries(flow)
          .where((entry) => entry.key == 'tapOn')
          .map((entry) => entry.value)
          .whereType<String>()
          .toList();
      bool accepts(String selector, String text) =>
          RegExp(selector).hasMatch(text);
      final schedule = taps.singleWhere(
        (value) => value.contains('Schedule date and time'),
      );
      expect(accepts(schedule, 'Schedule date and time'), isTrue);
      expect(accepts(schedule, 'Schedule date and time...'), isTrue);
      expect(accepts(schedule, 'Clear Schedule date and time'), isFalse);
      final habitOptions = taps.singleWhere(
        (value) => value.contains('Habit options'),
      );
      expect(accepts(habitOptions, 'Habit options, Collapsed'), isTrue);
      expect(accepts(habitOptions, 'Habit options, Expanded'), isTrue);
      expect(accepts(habitOptions, 'Habit options'), isTrue);
      expect(accepts(habitOptions, 'Other Habit options'), isFalse);
    },
  );

  test(
    'screen assertions retain every observed header and habit-state node independently',
    () {
      final observed = <String, List<String>>{
        '04-smart-planner': [
          'Choose a step',
          'Describe what you need to do. Get a manageable next step to review.',
        ],
        '05-creator': [
          'Add something',
          'Give it a name. Add details only if you need them.',
          'Maestro review rhythm',
          '1 time per day · Active',
          'Completed this day',
        ],
        '07-timeline': [
          'Schedule',
          'See tasks with dates and past activity. Open a task to update it.',
        ],
        '08-progression': [
          'Your recorded progress',
          'Activity',
          'Review completed tasks and recorded milestones. You can start again at any time.',
        ],
      };
      for (final flow in observed.entries) {
        final assertions = entries(commands('.maestro/flows/${flow.key}.yaml'))
            .where((entry) => entry.key == 'assertVisible')
            .map((entry) => entry.value)
            .whereType<String>();
        for (final label in flow.value) {
          expect(
            assertions.any(
              (selector) => RegExp(
                selector.replaceFirst('(?s)', ''),
                dotAll: selector.startsWith('(?s)'),
              ).hasMatch(label),
            ),
            isTrue,
            reason: '${flow.key} must assert the actual native node $label',
          );
        }
      }
    },
  );

  test(
    'Planner copy matches complete lines in the observed merged native node',
    () {
      final selectors =
          entries(commands('.maestro/flows/04-smart-planner.yaml'))
              .where((entry) => entry.key == 'assertVisible')
              .map((entry) => entry.value)
              .whereType<String>()
              .where(
                (value) =>
                    value.contains('Choose a step') ||
                    value.contains('Describe what'),
              )
              .toList();
      expect(selectors, hasLength(2));
      const title = 'Choose a step';
      const help =
          'Describe what you need to do. Get a manageable next step to review.';
      const merged = 'Back\nHelp with your next step\n$title\n$help';
      for (var index = 0; index < selectors.length; index++) {
        final matcher = RegExp(
          selectors[index].replaceFirst('(?s)', ''),
          dotAll: true,
        );
        final line = [title, help][index];
        expect(matcher.hasMatch(line), isTrue);
        expect(matcher.hasMatch(merged), isTrue);
        expect(matcher.hasMatch('Unrelated $line'), isFalse);
        expect(matcher.hasMatch('$line extra unrelated copy'), isFalse);
        expect(matcher.hasMatch('Back\nHelp with your next step'), isFalse);
      }
    },
  );

  test(
    'SI reveals clipped response sections without dropping response contracts',
    () {
      final flow = commands('.maestro/flows/06-si-console.yaml');
      final verified = <String>[];
      var phase = '';
      String? revealed;
      var completionObserved = false;
      for (final command in flow.whereType<Map<dynamic, dynamic>>()) {
        final input = command['inputText'];
        if (input is String) {
          phase = input;
          revealed = null;
          completionObserved = false;
        }
        final wait = command['extendedWaitUntil'];
        if (wait is Map) {
          final visible = wait['visible'] as String;
          if (phase == 'What evidence is missing?') {
            expect(
              visible,
              contains(
                'Read-only on-device response based on the selected records.',
              ),
            );
          } else if (phase == '/status') {
            expect(visible, contains('SI STATUS.*Read-only Chat:'));
          } else if (phase == '/not-real preserve this') {
            expect(
              visible,
              contains(
                'Unknown shortcut.*No part of the request was sent or discarded.',
              ),
            );
          } else if (phase == 'I want to kill myself') {
            expect(visible, "Let's pause and focus on your safety");
            verified.add('crisis');
          }
          completionObserved = true;
        }
        final scroll = command['scrollUntilVisible'];
        if (scroll is Map) {
          expect(
            completionObserved,
            isTrue,
            reason: 'Wait for the current reply before revealing it.',
          );
          revealed = (scroll['element'] as Map)['text'] as String;
          expect(scroll['visibilityPercentage'], 100);
          expect(
            scroll['direction'],
            revealed.contains('Processing mode:') ? 'UP' : 'DOWN',
          );
        }
        final assertion = command['assertVisible'];
        if (assertion is String &&
            (assertion.contains('Processing mode:') ||
                ['DIRECT ANSWER', 'RECOMMENDATION'].contains(assertion))) {
          // Replay the clipped viewport from the hosted failure: none of these
          // required sections can be assumed visible after following the footer.
          expect(
            revealed,
            assertion,
            reason: 'Reveal the required $phase section before asserting it.',
          );
          verified.add('$phase|$assertion');
          revealed = null;
        }
      }
      expect(verified, [
        'What evidence is missing?|(?s).*Processing mode: On device.*',
        'What evidence is missing?|DIRECT ANSWER',
        'What evidence is missing?|RECOMMENDATION',
        '/status|(?s).*Processing mode: On device.*',
        '/not-real preserve this|(?s).*Processing mode: On-device fallback.*',
        'crisis',
      ]);
      expect(
        entries(flow).where(
          (entry) =>
              entry.key == 'assertNotVisible' && entry.value == 'External AI',
        ),
        hasLength(4),
      );
    },
  );

  for (final String path in <String>[
    '.maestro/flows/05-creator.yaml',
    '.maestro/subflows/create-scheduled-task.yaml',
    '.maestro/flows/priority8-learned-lifecycle.yaml',
  ]) {
    test(
      '$path focuses the accessible title, including merged Android hints',
      () {
        final YamlList commands =
            loadYamlDocuments(File(path).readAsStringSync())[1].contents
                as YamlList;
        final List<String> titleSelectors = commands
            .whereType<YamlMap>()
            .map((YamlMap command) => command['tapOn'])
            .whereType<String>()
            .where((String selector) => selector.contains('Title'))
            .toList();
        expect(titleSelectors, isNotEmpty);
        for (final String selector in titleSelectors) {
          final RegExp matcher = RegExp(selector);
          expect(matcher.hasMatch('Title, required'), isTrue);
          expect(matcher.hasMatch('Title, required\nTitle *'), isTrue);
          expect(matcher.hasMatch('Title, required\r\nTitle *'), isTrue);
          expect(matcher.hasMatch('Description'), isFalse);
          expect(matcher.hasMatch('Task Title, required note'), isFalse);
        }
      },
    );
  }
}
