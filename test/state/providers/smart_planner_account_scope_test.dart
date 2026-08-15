import 'dart:async';

import 'package:fantastic_guacamole/state/providers/si_pipeline_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/execution_signals_provider.dart';
import 'package:fantastic_guacamole/state/providers/explainable_si_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/si_pipeline_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/si_aggregation_account_fixture.dart';

void main() {
  test('Smart Planner context is isolated from A through signed-out to B', () async {
    final fixture = SiAggregationAccountFixture();
    final container = fixture.createContainer();
    addTearDown(container.dispose);
    final aggregationSubscription =
        container.listen(siStateAggregationProvider, (_, _) {}, fireImmediately: true);
    final decisionSubscription =
        container.listen(siDecisionOutputProvider, (_, _) {}, fireImmediately: true);
    final modelSubscription = container.listen(
      smartCoachScreenModelProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final bootstrapSubscription = container.listen(
      extendedDomainBootstrapProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(aggregationSubscription.close);
    addTearDown(decisionSubscription.close);
    addTearDown(modelSubscription.close);
    addTearDown(bootstrapSubscription.close);
    fixture.activate('A');
    final aAggregation = await _dataWhere(
      container,
      siStateAggregationProvider,
      (value) =>
          value.profile.name == 'A_PROFILE' &&
          value.tasks.length == 1 && value.tasks.single.title == 'A_TASK',
    );
    final aDecision = await _dataWhere(
      container,
      siDecisionOutputProvider,
      (value) => value.nextAction == 'A_DECISION_TASK',
    );
    final aModel = await _dataWhere(
      container,
      smartCoachScreenModelProvider,
      (value) => value.decision.nextAction == 'A_DECISION_TASK',
    );
    await _dataWhere(
      container,
      extendedDomainBootstrapProvider,
      (_) => true,
    );
    _expectAccountA(
      container,
      aggregation: aAggregation,
      decision: aDecision,
      model: aModel,
    );

    fixture.signOut();
    final signedOutAggregation = await _dataWhere(
      container,
      siStateAggregationProvider,
      (value) => value.profile.name == 'signed_out',
    );
    final signedOutDecision = await _dataWhere(
      container,
      siDecisionOutputProvider,
      (value) => value.nextAction == 'Capture one high-value task.',
    );
    final signedOutModel = await _dataWhere(
      container,
      smartCoachScreenModelProvider,
      (value) => value.aggregation.profile.name == 'signed_out',
    );
    await _dataWhere(
      container,
      extendedDomainBootstrapProvider,
      (_) => true,
    );
    _expectSignedOut(
      container,
      aggregation: signedOutAggregation,
      decision: signedOutDecision,
      model: signedOutModel,
    );

    fixture.activate('B');
    final bAggregation = await _dataWhere(
      container,
      siStateAggregationProvider,
      (value) =>
          value.profile.name == 'B_PROFILE' &&
          value.tasks.length == 1 && value.tasks.single.title == 'B_TASK',
    );
    final bDecision = await _dataWhere(
      container,
      siDecisionOutputProvider,
      (value) => value.nextAction == 'B_DECISION_TASK',
    );
    final bModel = await _dataWhere(
      container,
      smartCoachScreenModelProvider,
      (value) => value.decision.nextAction == 'B_DECISION_TASK',
    );
    await _dataWhere(
      container,
      extendedDomainBootstrapProvider,
      (_) => true,
    );
    _expectAccountB(
      container,
      aggregation: bAggregation,
      decision: bDecision,
      model: bModel,
    );

    fixture.signOut();
    final returnSignedOutAggregation = await _dataWhere(
      container,
      siStateAggregationProvider,
      (value) => value.profile.name == 'signed_out',
    );
    final returnSignedOutDecision = await _dataWhere(
      container,
      siDecisionOutputProvider,
      (value) => value.nextAction == 'Capture one high-value task.',
    );
    final returnSignedOutModel = await _dataWhere(
      container,
      smartCoachScreenModelProvider,
      (value) => value.aggregation.profile.name == 'signed_out',
    );
    _expectSignedOut(
      container,
      aggregation: returnSignedOutAggregation,
      decision: returnSignedOutDecision,
      model: returnSignedOutModel,
    );

    fixture.activate('A');
    final returnedAAggregation = await _dataWhere(
      container,
      siStateAggregationProvider,
      (value) =>
          value.profile.name == 'A_PROFILE' &&
          value.tasks.length == 1 && value.tasks.single.title == 'A_TASK',
    );
    final returnedADecision = await _dataWhere(
      container,
      siDecisionOutputProvider,
      (value) => value.nextAction == 'A_DECISION_TASK',
    );
    final returnedAModel = await _dataWhere(
      container,
      smartCoachScreenModelProvider,
      (value) => value.decision.nextAction == 'A_DECISION_TASK',
    );
    await _dataWhere(container, extendedDomainBootstrapProvider, (_) => true);
    _expectAccountA(
      container,
      aggregation: returnedAAggregation,
      decision: returnedADecision,
      model: returnedAModel,
    );

    fixture.signOut();
    fixture.activate('B');
    fixture.signOut();
    fixture.activate('C');
    final cAggregation = await _dataWhere(
      container,
      siStateAggregationProvider,
      (value) =>
          value.profile.name == 'C_PROFILE' &&
          value.tasks.length == 1 && value.tasks.single.title == 'C_TASK',
    );
    final cDecision = await _dataWhere(
      container,
      siDecisionOutputProvider,
      (value) => value.nextAction == 'C_DECISION_TASK',
    );
    final cModel = await _dataWhere(
      container,
      smartCoachScreenModelProvider,
      (value) => value.decision.nextAction == 'C_DECISION_TASK',
    );
    await _dataWhere(container, extendedDomainBootstrapProvider, (_) => true);
    _expectAccountC(
      container,
      aggregation: cAggregation,
      decision: cDecision,
      model: cModel,
    );
  });
}

void _expectAccountA(
  ProviderContainer container, {
  required SIStateAggregation aggregation,
  required SIDecisionOutput decision,
  required SmartCoachScreenModel model,
}) {
  expect(aggregation.tasks.single.title, 'A_TASK');
  expect(decision.nextAction, 'A_DECISION_TASK');
  expect(model.aggregation.tasks.single.title, 'A_TASK');
  expect(model.decision.nextAction, 'A_DECISION_TASK');
  final execution = container.read(executionSignalsProvider);
  final explainable = container.read(explainableSIProvider);
  final siState = container.read(siStateProvider);
  final emotion = container.read(emotionProvider);
  expect(execution.completedToday, 2);
  expect(execution.completed7d, 2);
  expect(explainable.primaryReason, 'A_EXPLAINABLE_SI');
  expect(explainable.reasons.single.detail, 'A_EXPLAINABLE_SI');
  expect(siState.energy, .7);
  expect(siState.fatigue, .3);
  expect(siState.completedToday, 3);
  expect(emotion.name, 'focused');
  _expectNoForeignContext(<Object>[
      aggregation.profile.name,
      aggregation.tasks.single.title,
      decision.nextAction,
      model.aggregation.tasks.single.title,
      model.decision.nextAction,
      execution.completedToday,
      execution.completed7d,
      explainable.primaryReason,
      explainable.reasons.single.detail,
      siState.energy,
      siState.fatigue,
      siState.completedToday,
      emotion.name,
  ], <String>['B_', 'C_']);
}

void _expectSignedOut(
  ProviderContainer container, {
  required SIStateAggregation aggregation,
  required SIDecisionOutput decision,
  required SmartCoachScreenModel model,
}) {
  expect(aggregation.tasks, isEmpty);
  expect(aggregation.goals, isEmpty);
  expect(aggregation.profile.name, 'signed_out');
  expect(decision.nextAction, 'Capture one high-value task.');
  expect(model.aggregation.tasks, isEmpty);
  expect(model.decision.nextAction, 'Capture one high-value task.');
  final execution = container.read(executionSignalsProvider);
  final explainable = container.read(explainableSIProvider);
  final siState = container.read(siStateProvider);
  final emotion = container.read(emotionProvider);
  expect(execution.actionedToday, 0);
  expect(explainable.primaryReason, 'SIGNED_OUT_EXPLAINABLE_SI');
  expect(siState.energy, .5);
  expect(siState.fatigue, .5);
  expect(siState.completedToday, 0);
  expect(emotion.name, 'neutral');
  _expectNoAccountSentinels(<Object>[
    aggregation.profile.name,
    decision.nextAction,
    model.decision.nextAction,
    explainable.primaryReason,
    emotion.name,
  ]);
}

void _expectAccountB(
  ProviderContainer container, {
  required SIStateAggregation aggregation,
  required SIDecisionOutput decision,
  required SmartCoachScreenModel model,
}) {
  expect(aggregation.tasks.single.title, 'B_TASK');
  expect(decision.nextAction, 'B_DECISION_TASK');
  expect(model.aggregation.tasks.single.title, 'B_TASK');
  expect(model.decision.nextAction, 'B_DECISION_TASK');
  final execution = container.read(executionSignalsProvider);
  final explainable = container.read(explainableSIProvider);
  final siState = container.read(siStateProvider);
  final emotion = container.read(emotionProvider);
  expect(execution.completedToday, 2);
  expect(explainable.primaryReason, 'B_EXPLAINABLE_SI');
  expect(siState.energy, .7);
  expect(siState.fatigue, .58);
  expect(siState.completedToday, 1);
  expect(emotion.name, 'calm');
  _expectNoForeignContext(<Object>[
    aggregation.profile.name,
    aggregation.tasks.single.title,
    decision.nextAction,
    model.aggregation.tasks.single.title,
    model.decision.nextAction,
    explainable.primaryReason,
    explainable.reasons.single.detail,
    emotion.name,
  ], <String>['A_', 'C_']);
  _expectNoForeignContext(<Object>[
    aggregation.profile.name,
    aggregation.tasks.single.title,
    decision.nextAction,
    model.aggregation.tasks.single.title,
    model.decision.nextAction,
    explainable.primaryReason,
  ], <String>['A_', 'C_']);
}

void _expectAccountC(
  ProviderContainer container, {
  required SIStateAggregation aggregation,
  required SIDecisionOutput decision,
  required SmartCoachScreenModel model,
}) {
  expect(aggregation.tasks.single.title, 'C_TASK');
  expect(decision.nextAction, 'C_DECISION_TASK');
  expect(model.aggregation.tasks.single.title, 'C_TASK');
  expect(model.decision.nextAction, 'C_DECISION_TASK');
  final execution = container.read(executionSignalsProvider);
  final explainable = container.read(explainableSIProvider);
  final siState = container.read(siStateProvider);
  final emotion = container.read(emotionProvider);
  expect(execution.completedToday, 2);
  expect(explainable.primaryReason, 'C_EXPLAINABLE_SI');
  expect(siState.energy, .7);
  expect(siState.fatigue, .37);
  expect(siState.completedToday, 2);
  expect(emotion.name, 'energized');
  _expectNoForeignContext(<Object>[
    aggregation.profile.name,
    aggregation.tasks.single.title,
    decision.nextAction,
    model.aggregation.tasks.single.title,
    model.decision.nextAction,
    explainable.primaryReason,
    explainable.reasons.single.detail,
    emotion.name,
  ], <String>['A_', 'B_']);
}

void _expectNoAccountSentinels(List<Object> values) {
  final context = values.join('|');
  expect(context, isNot(contains('A_')));
  expect(context, isNot(contains('B_')));
  expect(context, isNot(contains('C_')));
}

void _expectNoForeignContext(List<Object> values, List<String> sentinels) {
  final context = values.join('|');
  for (final sentinel in sentinels) {
    expect(context, isNot(contains(sentinel)));
  }
}

Future<T> _dataWhere<T>(
  ProviderContainer container,
  FutureProvider<T> provider,
  bool Function(T value) matches,
) async {
  final result = Completer<T>();
  late ProviderSubscription<AsyncValue<T>> sub;
  sub = container.listen(provider, (_, next) {
    if (next.hasValue && matches(next.requireValue) && !result.isCompleted) {
      result.complete(next.requireValue);
    }
    if (next.hasError && !result.isCompleted) {
      result.completeError(next.error!, next.stackTrace);
    }
  }, fireImmediately: true);
  try { return await result.future.timeout(const Duration(seconds: 3)); } finally { sub.close(); }
}
