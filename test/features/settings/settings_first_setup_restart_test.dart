import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_task_repository.dart';
import 'package:fantastic_guacamole/features/settings/ui/settings_screen.dart';
import 'package:fantastic_guacamole/state/core/app_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_onboarding_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'restart first setup resets onboarding only and routes to onboarding',
    (WidgetTester tester) async {
      final AccountStorageScope scope = AccountStorageScope.authenticated(
        'settings-restart-user',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        onboardingCompleteStorageKey: true,
        onboardingWelcomeCompleteStorageKey: true,
        onboardingContentVersionStorageKey: 7,
        'onboarding_profile_complete_v1.${scope.v2Namespace}': true,
        'tasks_storage_sentinel': 'keep-task-data',
      });
      final _TaskRepository repository = _TaskRepository(<TaskEntity>[
        TaskEntity(
          id: 'retained-task',
          title: 'Keep this task',
          createdAt: DateTime.utc(2026, 8, 30, 9),
          scheduledFor: DateTime.utc(2026, 8, 30, 10),
        ),
      ]);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWithValue(scope),
          accountLegacyOwnershipProvider.overrideWithValue(
            LegacyScopeOwnership.provenNotOwned,
          ),
          domainTaskRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      container.read(onboardingCompleteProvider.notifier).set(true);
      container.read(onboardingWelcomeCompleteProvider.notifier).set(true);
      expect(
        await container.read(accountOnboardingCompleteProvider.future),
        isTrue,
      );
      final AdaptiveGuidanceState guidanceBefore = await container.read(
        adaptiveGuidanceProvider.future,
      );
      expect(guidanceBefore.has(GuidanceMilestone.firstItem), isTrue);
      expect(guidanceBefore.has(GuidanceMilestone.firstSchedule), isTrue);

      final GoRouter router = GoRouter(
        initialLocation: RoutePaths.settings,
        routes: <RouteBase>[
          GoRoute(
            path: RoutePaths.settings,
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? child) {
                  return TextButton(
                    onPressed: () async {
                      await restartFirstSetup(context, ref);
                    },
                    child: const Text('Restart first setup'),
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: RoutePaths.onboarding,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('Onboarding destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.tap(find.text('Restart first setup'));
      await tester.pumpAndSettle();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(find.text('Onboarding destination'), findsOneWidget);
      expect(prefs.getBool(onboardingCompleteStorageKey), isFalse);
      expect(prefs.getBool(onboardingWelcomeCompleteStorageKey), isFalse);
      expect(prefs.getInt(onboardingContentVersionStorageKey), 0);
      expect(
        prefs.getBool('onboarding_profile_complete_v1.${scope.v2Namespace}'),
        isFalse,
      );
      expect(prefs.getString('tasks_storage_sentinel'), 'keep-task-data');
      expect(container.read(onboardingCompleteProvider), isFalse);
      expect(container.read(onboardingWelcomeCompleteProvider), isFalse);
      expect(
        await container.read(accountOnboardingCompleteProvider.future),
        isFalse,
      );

      final AdaptiveGuidanceState guidanceAfter = container
          .read(adaptiveGuidanceProvider)
          .requireValue;
      expect(guidanceAfter.milestones, guidanceBefore.milestones);
      expect(guidanceAfter.replayLessons, isEmpty);
      expect(repository.tasks.single.id, 'retained-task');
      expect(repository.mutationCount, 0);
    },
  );
}

class _TaskRepository implements ITaskRepository {
  _TaskRepository(this.tasks);

  final List<TaskEntity> tasks;
  int mutationCount = 0;

  @override
  Future<void> deleteTask(String id) async {
    mutationCount += 1;
  }

  @override
  Future<List<TaskEntity>> getAllTasks() async => tasks;

  @override
  Future<TaskEntity?> getTaskById(String id) async =>
      tasks.where((TaskEntity task) => task.id == id).firstOrNull;

  @override
  Future<void> saveTask(TaskEntity task) async {
    mutationCount += 1;
  }
}
