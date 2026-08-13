import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/data/repositories/goal_repository.dart';
import 'package:fantastic_guacamole/data/repositories/task_repository.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A4 audit: selected lifecycle invalidations recreate Task and Goal domain adapters', () {
    AccountStorageScope scope = AccountStorageScope.authenticated('account-a');
    final ProviderContainer container = ProviderContainer(
      overrides: [
        accountStorageScopeProvider.overrideWith((Ref ref) => scope),
        taskRepositoryProvider.overrideWith((Ref ref) => TaskRepository.unavailable()),
        goalRepositoryProvider.overrideWith((Ref ref) => GoalRepository.unavailable()),
      ],
    );
    addTearDown(container.dispose);

    final Object taskAdapterA = container.read(domainTaskRepositoryProvider);
    final Object goalAdapterA = container.read(domainGoalRepositoryProvider);
    final Object getTasksA = container.read(getTasksUseCaseProvider);
    final Object getGoalsA = container.read(getGoalsUseCaseProvider);
    final Object createTaskA = container.read(createTaskUseCaseProvider);
    final Object completeTaskA = container.read(completeTaskUseCaseProvider);
    final Object updateTaskA = container.read(updateTaskUseCaseProvider);
    final Object createGoalA = container.read(featureCreateGoalUseCaseProvider);
    final Object updateGoalA = container.read(featureUpdateGoalUseCaseProvider);
    final Object deleteGoalA = container.read(deleteGoalUseCaseProvider);
    final Object completeGoalA = container.read(completeGoalUseCaseProvider);
    final Object taskRepositoryA = container.read(taskRepositoryProvider);
    final Object goalRepositoryA = container.read(goalRepositoryProvider);

    scope = AccountStorageScope.authenticated('account-b');
    container.invalidate(accountStorageScopeProvider);
    container.invalidate(taskRepositoryProvider);
    container.invalidate(goalRepositoryProvider);
    container.invalidate(domainTaskRepositoryProvider);
    container.invalidate(domainGoalRepositoryProvider);
    container.invalidate(getTasksUseCaseProvider);
    container.invalidate(getGoalsUseCaseProvider);
    container.invalidate(createTaskUseCaseProvider);
    container.invalidate(completeTaskUseCaseProvider);
    container.invalidate(updateTaskUseCaseProvider);
    container.invalidate(featureCreateGoalUseCaseProvider);
    container.invalidate(featureUpdateGoalUseCaseProvider);
    container.invalidate(deleteGoalUseCaseProvider);
    container.invalidate(completeGoalUseCaseProvider);

    final Object taskRepositoryB = container.read(taskRepositoryProvider);
    final Object goalRepositoryB = container.read(goalRepositoryProvider);
    final Object taskAdapterB = container.read(domainTaskRepositoryProvider);
    final Object goalAdapterB = container.read(domainGoalRepositoryProvider);

    expect(identical(taskRepositoryA, taskRepositoryB), isFalse);
    expect(identical(goalRepositoryA, goalRepositoryB), isFalse);
    expect(identical(taskAdapterA, taskAdapterB), isFalse);
    expect(identical(goalAdapterA, goalAdapterB), isFalse);
    expect(identical(getTasksA, container.read(getTasksUseCaseProvider)), isFalse);
    expect(identical(getGoalsA, container.read(getGoalsUseCaseProvider)), isFalse);
    expect(identical(createTaskA, container.read(createTaskUseCaseProvider)), isFalse);
    expect(identical(completeTaskA, container.read(completeTaskUseCaseProvider)), isFalse);
    expect(identical(updateTaskA, container.read(updateTaskUseCaseProvider)), isFalse);
    expect(identical(createGoalA, container.read(featureCreateGoalUseCaseProvider)), isFalse);
    expect(identical(updateGoalA, container.read(featureUpdateGoalUseCaseProvider)), isFalse);
    expect(identical(deleteGoalA, container.read(deleteGoalUseCaseProvider)), isFalse);
    expect(identical(completeGoalA, container.read(completeGoalUseCaseProvider)), isFalse);
  });
}
