import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/repositories/decision_outcome_repository.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final decisionOutcomeRepositoryProvider = Provider<DecisionOutcomeRepository?>((
  Ref ref,
) {
  final AccountStorageScope scope = ref.watch(accountStorageScopeProvider);
  if (!scope.isWritable) return null;
  return DecisionOutcomeRepository(ref.read(sharedPrefsStoreProvider), scope);
});

final decisionOutcomesProvider = FutureProvider<List<DecisionOutcomeEntity>>((
  Ref ref,
) async {
  final DecisionOutcomeRepository? repository = ref.watch(
    decisionOutcomeRepositoryProvider,
  );
  return repository?.load() ?? const <DecisionOutcomeEntity>[];
});

final decisionOutcomeActionsProvider = Provider<DecisionOutcomeActions>(
  DecisionOutcomeActions.new,
);

class DecisionOutcomeActions {
  DecisionOutcomeActions(this._ref);

  final Ref _ref;

  Future<void> record({
    required OperatingDecisionReceipt receipt,
    required DecisionOutcomeKind kind,
    required String surface,
    String? detail,
  }) async {
    final AccountStorageScope before = _ref.read(accountStorageScopeProvider);
    final DecisionOutcomeRepository? repository = _ref.read(
      decisionOutcomeRepositoryProvider,
    );
    if (!before.isWritable || repository == null) return;
    await repository.record(
      DecisionOutcomeEntity(
        decisionId: receipt.decisionId,
        kind: kind,
        surface: surface,
        recordedAt: DateTime.now().toUtc(),
        modelVersion: receipt.modelVersion,
        recommendationConfidence: receipt.recommendationConfidence,
        subjectId: receipt.subjectId,
        detail: detail,
      ),
    );
    final AccountStorageScope after = _ref.read(accountStorageScopeProvider);
    if (after.v2Namespace == before.v2Namespace && after.isWritable) {
      _ref.invalidate(decisionOutcomesProvider);
    }
  }
}
