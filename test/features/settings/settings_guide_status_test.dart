import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _account = 'settings-guide-status-user';

void main() {
  const String prefix = 'adaptive_guidance_v3';
  final String namespace = AccountStorageScope.authenticated(
    _account,
  ).v2Namespace!;
  final Map<String, Object> pausedByOldVersion = <String, Object>{
    for (final String id in <String>[
      'createFirstItem',
      'scheduleFirstItem',
      'reviewTimeline',
    ])
      '$prefix.$namespace.later.$id': true,
  };
  final Map<String, Object> skipped = <String, Object>{
    for (final String id in <String>[
      'createFirstItem',
      'scheduleFirstItem',
      'reviewTimeline',
    ])
      '$prefix.$namespace.skip.$id': true,
  };

  for (final bool es in <bool>[false, true]) {
    final String lang = es ? 'Spanish' : 'English';

    testWidgets('$lang Settings reports a paused guide truthfully', (
      WidgetTester tester,
    ) async {
      await _pump(tester, pausedByOldVersion, es: es);
      expect(find.text(es ? 'Guía en pausa' : 'Guide paused'), findsOneWidget);
      expect(
        find.text(es ? 'Guía en curso' : 'Guide in progress'),
        findsNothing,
      );
      expect(
        find.textContaining(
          es ? 'tarjetas de ayuda ocultas' : 'help cards hidden',
        ),
        findsNothing,
      );
      expect(
        find.text(
          es ? 'Reiniciar la Guía Adaptativa' : 'Restart Adaptive Guide',
        ),
        findsOneWidget,
      );
    });

    testWidgets('$lang Settings reports a skipped guide truthfully', (
      WidgetTester tester,
    ) async {
      await _pump(tester, skipped, es: es);
      expect(find.text(es ? 'Guía omitida' : 'Guide skipped'), findsOneWidget);
      expect(
        find.textContaining(
          es ? 'Reinicia la guía abajo' : 'Restart the guide below',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          es ? 'Reiniciar la Guía Adaptativa' : 'Restart Adaptive Guide',
        ),
        findsOneWidget,
      );
    });
  }

  // "Skip this step" on every remaining step ends the guide; it moved on
  // after the first skip and stopped after the last.
  final Map<String, Object> everyStepSkipped = <String, Object>{
    for (final String id in <String>[
      'createFirstItem',
      'scheduleFirstItem',
      'reviewTimeline',
    ])
      '$prefix.$namespace.skipStep.$id': true,
  };
  final Map<String, Object> firstStepSkipped = <String, Object>{
    '$prefix.$namespace.skipStep.createFirstItem': true,
    '$prefix.$namespace.skipStep.scheduleFirstItem': true,
    '$prefix.$namespace.expected_first_run_creator_task_ids': <String>[
      'saved-task',
    ],
  };

  testWidgets('Settings reports a guide ended by Skip this step as skipped', (
    WidgetTester tester,
  ) async {
    await _pump(tester, everyStepSkipped, es: false);
    expect(find.text('Guide skipped'), findsOneWidget);
    expect(find.textContaining('Restart the guide below'), findsOneWidget);
    expect(find.text('Guide paused'), findsNothing);
  });

  testWidgets('after Skip this step with a step left, the guide is still '
      'active', (WidgetTester tester) async {
    await _pump(tester, firstStepSkipped, es: false);
    expect(find.text('Guide in progress'), findsOneWidget);
    // A skipped step is not a hidden help card.
    expect(find.textContaining('0 help cards hidden'), findsOneWidget);
    expect(find.text('Guide skipped'), findsNothing);
  });

  for (final bool es in <bool>[false, true]) {
    testWidgets('${es ? 'Spanish' : 'English'} status counts in plain words, '
        'singular and plural', (WidgetTester tester) async {
      await _pump(tester, <String, Object>{}, es: es);
      expect(
        find.text(es ? 'Guía en curso' : 'Guide in progress'),
        findsOneWidget,
      );
      expect(
        find.text(
          es
              ? '0 acciones registradas · 0 tarjetas de ayuda ocultas'
              : '0 actions recorded · 0 help cards hidden',
        ),
        findsOneWidget,
      );

      await _pump(tester, <String, Object>{
        '$prefix.$namespace.firstItem.at': 1755475200000,
        '$prefix.$namespace.firstItem.count': 1,
        '$prefix.$namespace.skip.nexus': true,
      }, es: es);
      expect(
        find.text(
          es
              ? '1 acción registrada · 1 tarjeta de ayuda oculta'
              : '1 action recorded · 1 help card hidden',
        ),
        findsOneWidget,
      );

      await _pump(tester, <String, Object>{
        for (final String id in <String>[
          'firstItem',
          'firstSchedule',
        ]) ...<String, Object>{
          '$prefix.$namespace.$id.at': 1755475200000,
          '$prefix.$namespace.$id.count': 1,
        },
        for (final String id in <String>['nexus', 'goals', 'habits'])
          '$prefix.$namespace.skip.$id': true,
      }, es: es);
      expect(
        find.text(
          es
              ? '2 acciones registradas · 3 tarjetas de ayuda ocultas'
              : '2 actions recorded · 3 help cards hidden',
        ),
        findsOneWidget,
      );

      await _pump(tester, skipped, es: es);
      expect(
        find.text(
          es
              ? '0 acciones registradas · Reinicia la guía abajo para continuar.'
              : '0 actions recorded · Restart the guide below to continue.',
        ),
        findsOneWidget,
      );

      await _pump(tester, <String, Object>{
        for (final String id in <String>[
          'firstItem',
          'firstSchedule',
          'firstTimelineReview',
        ]) ...<String, Object>{
          '$prefix.$namespace.$id.at': 1755475200000,
          '$prefix.$namespace.$id.count': 1,
        },
      }, es: es);
      expect(
        find.text(es ? 'Guía terminada' : 'Guide finished'),
        findsOneWidget,
      );
      expect(find.textContaining('real outcomes'), findsNothing);
      expect(find.textContaining('resultados reales'), findsNothing);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  Map<String, Object> stored, {
  required bool es,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      accountStorageScopeProvider.overrideWithValue(
        AccountStorageScope.authenticated(_account),
      ),
      domainTaskRepositoryProvider.overrideWithValue(_NoTasks()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(adaptiveGuidanceProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(es ? 'es' : 'en'),
        supportedLocales: ChronoSparkLocalizations.supportedLocales,
        localizationsDelegates: const [
          ChronoSparkLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: AdaptiveGuidanceSettingsSection()),
      ),
    ),
  );
  await tester.pump();
}

class _NoTasks implements ITaskRepository {
  @override
  Future<List<TaskEntity>> getAllTasks() async => <TaskEntity>[];
  @override
  Future<TaskEntity?> getTaskById(String id) async => null;
  @override
  Future<void> saveTask(TaskEntity task) async {}
  @override
  Future<void> deleteTask(String id) async {}
}
