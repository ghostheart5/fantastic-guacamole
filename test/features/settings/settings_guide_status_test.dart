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
        find.text(
          es ? 'Aprendiendo el flujo principal' : 'Learning the core workflow',
        ),
        findsNothing,
      );
      expect(
        find.textContaining(es ? 'avisos silenciados' : 'prompts muted'),
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

  testWidgets('an active guide keeps the existing status text', (
    WidgetTester tester,
  ) async {
    await _pump(tester, <String, Object>{}, es: false);
    expect(find.text('Learning the core workflow'), findsOneWidget);
    expect(find.textContaining('0 prompts muted'), findsOneWidget);
  });
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
