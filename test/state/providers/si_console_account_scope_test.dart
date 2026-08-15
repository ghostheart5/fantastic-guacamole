import 'dart:async';

import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/si_aggregation_account_fixture.dart';

void main() {
  test('real SI Console model keeps workspace and context account coherent', () async {
    final SiAggregationAccountFixture fixture = SiAggregationAccountFixture();
    final ProviderContainer container = fixture.createContainer();
    addTearDown(container.dispose);

    fixture.activate('A');
    await _seedWorkspace(container, 'A_SECRET_QUERY_CONTEXT');
    expect(await _workspaceQuery(container), 'shared-query');
    final SIConsoleScreenModel a = await _readFor(container, 'A_DECISION_TASK');
    expect(a.aggregation.profile.name, 'A_PROFILE');
    expect(a.aggregation.tasks.single.title, 'A_TASK');
    expect(a.aggregation.memories.single.text, 'A_MEMORY');
    expect(a.engineSnapshot, contains('A_SECRET_QUERY_CONTEXT'));

    fixture.signOut();
    final SIConsoleScreenModel signedOut = await _readFor(
      container,
      'Capture one high-value task.',
    );
    expect(signedOut.aggregation.profile.name, 'signed_out');
    expect(signedOut.aggregation.tasks, isEmpty);
    expect(signedOut.aggregation.memories, isEmpty);
    expect(signedOut.engineSnapshot, isNot(contains('A_SECRET_QUERY_CONTEXT')));

    fixture.activate('B');
    await _seedWorkspace(container, 'B_SECRET_QUERY_CONTEXT');
    expect(await _workspaceQuery(container), 'shared-query');
    final SIConsoleScreenModel b = await _readFor(container, 'B_DECISION_TASK');
    expect(b.aggregation.profile.name, 'B_PROFILE');
    expect(b.aggregation.tasks.single.title, 'B_TASK');
    expect(b.aggregation.memories.single.text, 'B_MEMORY');
    expect(b.aggregation.trajectory.alert, 'B_TRAJECTORY');
    expect(b.aggregation.soulMap.recommendations, contains('B_SOULMAP_ALIGNMENT'));
    expect(b.engineSnapshot, contains('B_SECRET_QUERY_CONTEXT'));
    expect(b.decision.nextAction, isNot(contains('A_')));
    expect(b.engineSnapshot, isNot(contains('A_SECRET_QUERY_CONTEXT')));

    fixture.signOut();
    fixture.activate('A');
    final SIConsoleScreenModel restoredA = await _readFor(container, 'A_DECISION_TASK');
    expect(restoredA.aggregation.memories.single.text, 'A_MEMORY');
    expect(restoredA.aggregation.trajectory.alert, 'A_TRAJECTORY');
    expect(restoredA.engineSnapshot, contains('A_SECRET_QUERY_CONTEXT'));
    expect(restoredA.engineSnapshot, isNot(contains('B_SECRET_QUERY_CONTEXT')));

    fixture.signOut();
    fixture.activate('C');
    await _seedWorkspace(container, 'C_SECRET_QUERY_CONTEXT');
    final SIConsoleScreenModel c = await _readFor(container, 'C_DECISION_TASK');
    expect(c.aggregation.profile.name, 'C_PROFILE');
    expect(c.aggregation.memories.single.text, 'C_MEMORY');
    expect(c.aggregation.trajectory.alert, 'C_TRAJECTORY');
    expect(c.aggregation.soulMap.recommendations, contains('C_SOULMAP_ALIGNMENT'));
    expect(c.engineSnapshot, contains('C_SECRET_QUERY_CONTEXT'));
    expect(c.engineSnapshot, isNot(anyOf(contains('A_SECRET_QUERY_CONTEXT'), contains('B_SECRET_QUERY_CONTEXT'))));
  });
}

Future<String> _workspaceQuery(ProviderContainer container) async {
  final Map<String, dynamic>? workspace = await container
      .read(siWorkspaceStoreProvider)
      .load();
  return ((workspace!['history'] as List<dynamic>).single
      as Map<String, dynamic>)['content'] as String;
}

Future<void> _seedWorkspace(ProviderContainer container, String marker) async {
  await container.read(siWorkspaceStoreProvider).save(<String, dynamic>{
    'personality': 'coach',
    'emotion': marker,
    'confidence': .9,
    'history': <Map<String, String>>[
      <String, String>{'role': 'user', 'content': 'shared-query'},
    ],
  });
  container.invalidate(siEngineStateProvider);
  container.invalidate(siConsoleScreenModelProvider);
}

Future<SIConsoleScreenModel> _readFor(
  ProviderContainer container,
  String expectedAction,
) async {
  final Completer<SIConsoleScreenModel> result = Completer<SIConsoleScreenModel>();
  late ProviderSubscription<AsyncValue<SIConsoleScreenModel>> subscription;
  subscription = container.listen(
    siConsoleScreenModelProvider,
    (_, AsyncValue<SIConsoleScreenModel> next) {
      if (next.hasValue && next.requireValue.decision.nextAction == expectedAction && !result.isCompleted) {
        result.complete(next.requireValue);
      }
      if (next.hasError && !result.isCompleted) {
        result.completeError(next.error!, next.stackTrace);
      }
    },
    fireImmediately: true,
  );
  try {
    return await result.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}
