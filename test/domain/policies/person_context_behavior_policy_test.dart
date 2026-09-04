import 'dart:convert';

import 'package:fantastic_guacamole/domain/entities/assistant_evidence_plane.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/domain/policies/person_context_behavior_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 2, 12);

  test(
    'policy matrix is exhaustive and every rule forbids identity inference',
    () {
      expect(
        PersonContextBehaviorPolicy.matrix.keys.toSet(),
        PersonContextKind.values.toSet(),
      );
      expect(_expectedRules.keys.toSet(), PersonContextKind.values.toSet());

      for (final PersonContextKind kind in PersonContextKind.values) {
        final PersonContextBehaviorRule rule =
            PersonContextBehaviorPolicy.ruleFor(kind);
        final _ExpectedRule expected = _expectedRules[kind]!;

        expect(rule.kind, kind, reason: kind.name);
        expect(rule.purpose, expected.purpose, reason: kind.name);
        expect(rule.relevanceRule, expected.relevanceRule, reason: kind.name);
        expect(rule.maxFreshness, expected.maxFreshness, reason: kind.name);
        expect(rule.permittedField, expected.permittedField, reason: kind.name);
        expect(rule.effectSize, expected.effectSize, reason: kind.name);
        expect(
          rule.conflictAuthority,
          expected.conflictAuthority,
          reason: kind.name,
        );
        expect(
          rule.overrideBehavior,
          expected.overrideBehavior,
          reason: kind.name,
        );
        expect(
          rule.allowedSurfaces,
          expected.allowedSurfaces,
          reason: kind.name,
        );
        expect(
          rule.prohibitedInferences,
          contains(PersonContextProhibitedInference.stableIdentityOrTrait),
          reason: kind.name,
        );
        expect(
          rule.allowedSurfaces,
          isNot(contains(PersonContextSurface.settings)),
          reason: kind.name,
        );
      }
    },
  );

  test('relevant fresh consented context changes only its permitted field', () {
    for (final PersonContextKind kind in PersonContextKind.values) {
      final PersonContextBehaviorRule rule =
          PersonContextBehaviorPolicy.ruleFor(kind);
      final PersonContextSurface surface = rule.allowedSurfaces.first;
      final PersonContextSignal signal = _signalFor(
        kind,
        now: now,
        surface: surface,
      );
      final Map<PersonContextBehaviorField, Object?> baseline =
          <PersonContextBehaviorField, Object?>{
            for (final PersonContextBehaviorField field
                in PersonContextBehaviorField.values)
              field: 'baseline-${field.name}',
          };
      final PersonContextBehaviorTrace trace =
          PersonContextBehaviorPolicy.evaluate(
            signals: <PersonContextSignal>[signal],
            surface: surface,
            purposes: <PersonContextPurpose>{rule.purpose},
            relevance: <String, PersonContextRelevanceBasis>{
              signal.id: _basisFor(rule.relevanceRule),
            },
            now: now,
            noContextBaseline: baseline,
          );
      final PersonContextBehaviorApplication application =
          PersonContextBehaviorPolicy.apply(
            trace: trace,
            effects: <PersonContextBehaviorEffect>[
              PersonContextBehaviorEffect(
                signalId: signal.id,
                field: rule.permittedField,
                value: 'applied-${kind.name}',
              ),
            ],
          );

      expect(trace.rejected, isEmpty, reason: kind.name);
      expect(trace.used, hasLength(1), reason: kind.name);
      expect(application.trace.changedFields, <PersonContextBehaviorField>{
        rule.permittedField,
      }, reason: kind.name);
      for (final PersonContextBehaviorField field
          in PersonContextBehaviorField.values) {
        expect(
          application.output[field],
          field == rule.permittedField
              ? 'applied-${kind.name}'
              : baseline[field],
          reason: '${kind.name}:${field.name}',
        );
      }
      expect(trace.used.single.effectSize, rule.effectSize, reason: kind.name);
      expect(
        trace.used.single.overrideBehavior,
        rule.overrideBehavior,
        reason: kind.name,
      );
    }
  });

  test(
    'irrelevant stale and withdrawn context make no change for every kind',
    () {
      for (final PersonContextKind kind in PersonContextKind.values) {
        final PersonContextBehaviorRule rule =
            PersonContextBehaviorPolicy.ruleFor(kind);
        final PersonContextSurface surface = rule.allowedSurfaces.first;

        PersonContextBehaviorTrace evaluate(PersonContextSignal signal) =>
            PersonContextBehaviorPolicy.evaluate(
              signals: <PersonContextSignal>[signal],
              surface: surface,
              purposes: <PersonContextPurpose>{rule.purpose},
              relevance: <String, PersonContextRelevanceBasis>{
                signal.id: _basisFor(rule.relevanceRule),
              },
              now: now,
              noContextBaseline: const <PersonContextBehaviorField, Object?>{},
            );

        final PersonContextBehaviorTrace irrelevant =
            PersonContextBehaviorPolicy.evaluate(
              signals: <PersonContextSignal>[
                _signalFor(kind, now: now, surface: surface),
              ],
              surface: surface,
              purposes: <PersonContextPurpose>{rule.purpose},
              relevance: const <String, PersonContextRelevanceBasis>{},
              now: now,
              noContextBaseline: const <PersonContextBehaviorField, Object?>{},
            );
        final PersonContextBehaviorTrace stale = evaluate(
          _signalFor(kind, now: now, surface: surface, stale: true),
        );
        final PersonContextBehaviorTrace withdrawn = evaluate(
          _signalFor(kind, now: now, surface: surface, withdrawn: true),
        );

        expect(irrelevant.changedFields, isEmpty, reason: kind.name);
        expect(
          irrelevant.rejected.single.rejectionReason,
          PersonContextRejectionReason.irrelevant,
          reason: kind.name,
        );
        expect(stale.changedFields, isEmpty, reason: kind.name);
        expect(
          stale.rejected.single.rejectionReason,
          PersonContextRejectionReason.stale,
          reason: kind.name,
        );
        expect(withdrawn.changedFields, isEmpty, reason: kind.name);
        expect(
          withdrawn.rejected.single.rejectionReason,
          PersonContextRejectionReason.consentWithdrawn,
          reason: kind.name,
        );
      }
    },
  );

  test('purpose surface source and policy freshness fail closed', () {
    final PersonContextBehaviorTrace wrongPurpose =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[
            _signalFor(
              PersonContextKind.role,
              now: now,
              purpose: PersonContextPurpose.planningGuidance,
            ),
          ],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.planningGuidance,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'signal-role': PersonContextRelevanceBasis.exactTextMatch,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );
    final PersonContextBehaviorTrace wrongSurface =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[
            _signalFor(
              PersonContextKind.outcomeHistory,
              now: now,
              surface: PersonContextSurface.nexus,
            ),
          ],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.outcomeLearning,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'signal-outcomeHistory':
                PersonContextRelevanceBasis.typedConfirmedOutcome,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );
    final PersonContextBehaviorTrace unconsentedSurface =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[
            _signalFor(
              PersonContextKind.role,
              now: now,
              surface: PersonContextSurface.smartPlanner,
            ),
          ],
          surface: PersonContextSurface.creator,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.decisionSupport,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'signal-role': PersonContextRelevanceBasis.exactTextMatch,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );
    final PersonContextBehaviorTrace unconfirmedOutcome =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[
            _signalFor(
              PersonContextKind.outcomeHistory,
              now: now,
              source: PersonContextSource.userAuthored,
            ),
          ],
          surface: PersonContextSurface.nexus,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.outcomeLearning,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'signal-outcomeHistory':
                PersonContextRelevanceBasis.typedConfirmedOutcome,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );
    final PersonContextBehaviorTrace overlongFreshness =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[
            _signalFor(
              PersonContextKind.currentPriority,
              now: now,
              freshness: const Duration(days: 31),
            ),
          ],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.decisionSupport,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'signal-currentPriority':
                PersonContextRelevanceBasis.typedActivePlanningWindow,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );

    expect(
      wrongPurpose.rejected.single.rejectionReason,
      PersonContextRejectionReason.purposeNotAllowed,
    );
    expect(
      wrongSurface.rejected.single.rejectionReason,
      PersonContextRejectionReason.surfaceNotAllowed,
    );
    expect(
      unconsentedSurface.rejected.single.rejectionReason,
      PersonContextRejectionReason.surfaceNotConsented,
    );
    expect(
      unconfirmedOutcome.rejected.single.rejectionReason,
      PersonContextRejectionReason.sourceNotAllowed,
    );
    expect(
      overlongFreshness.rejected.single.rejectionReason,
      PersonContextRejectionReason.freshnessWindowExceeded,
    );
  });

  test('conflicts use the single binder-required authority order', () {
    expect(
      PersonContextBehaviorPolicy.conflictOrder,
      const <PersonContextConflictAuthority>[
        PersonContextConflictAuthority.boundary,
        PersonContextConflictAuthority.safety,
        PersonContextConflictAuthority.scheduledCommitment,
        PersonContextConflictAuthority.freshCapacity,
        PersonContextConflictAuthority.currentPriority,
        PersonContextConflictAuthority.preferenceOrWording,
      ],
    );

    const List<PersonContextKind> inputOrder = <PersonContextKind>[
      PersonContextKind.preferredSupportStyle,
      PersonContextKind.currentPriority,
      PersonContextKind.presentCapacity,
      PersonContextKind.commitment,
      PersonContextKind.boundary,
    ];
    final PersonContextBehaviorTrace trace =
        PersonContextBehaviorPolicy.evaluate(
          signals: inputOrder
              .map((PersonContextKind kind) => _signalFor(kind, now: now))
              .toList(growable: false),
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.planningGuidance,
            PersonContextPurpose.decisionSupport,
          },
          relevance: <String, PersonContextRelevanceBasis>{
            for (final PersonContextKind kind in inputOrder)
              'signal-${kind.name}': _basisFor(
                PersonContextBehaviorPolicy.ruleFor(kind).relevanceRule,
              ),
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );

    expect(
      trace.used.map((PersonContextBehaviorDecision value) => value.kind),
      <PersonContextKind>[
        PersonContextKind.boundary,
        PersonContextKind.commitment,
        PersonContextKind.presentCapacity,
        PersonContextKind.currentPriority,
        PersonContextKind.preferredSupportStyle,
      ],
    );

    final PersonContextBehaviorTrace safetyConflict =
        PersonContextBehaviorPolicy.evaluate(
          signals: inputOrder
              .map((PersonContextKind kind) => _signalFor(kind, now: now))
              .toList(growable: false),
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.planningGuidance,
            PersonContextPurpose.decisionSupport,
          },
          relevance: <String, PersonContextRelevanceBasis>{
            for (final PersonContextKind kind in inputOrder)
              'signal-${kind.name}': _basisFor(
                PersonContextBehaviorPolicy.ruleFor(kind).relevanceRule,
              ),
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
          safetyGateActive: true,
        );
    expect(
      safetyConflict.used.map(
        (PersonContextBehaviorDecision decision) => decision.kind,
      ),
      const <PersonContextKind>[PersonContextKind.boundary],
    );
    expect(
      safetyConflict.rejected.map(
        (PersonContextBehaviorDecision decision) => decision.rejectionReason,
      ),
      everyElement(PersonContextRejectionReason.safetyPreempted),
    );

    final PersonContextSignal olderPriority = _signalFor(
      PersonContextKind.currentPriority,
      id: 'priority-older',
      now: now.subtract(const Duration(hours: 1)),
    );
    final PersonContextSignal newerPriority = _signalFor(
      PersonContextKind.currentPriority,
      id: 'priority-newer',
      now: now,
    );
    final PersonContextBehaviorTrace
    sameFieldConflict = PersonContextBehaviorPolicy.evaluate(
      signals: <PersonContextSignal>[olderPriority, newerPriority],
      surface: PersonContextSurface.smartPlanner,
      purposes: const <PersonContextPurpose>{
        PersonContextPurpose.decisionSupport,
      },
      relevance: const <String, PersonContextRelevanceBasis>{
        'priority-older': PersonContextRelevanceBasis.typedActivePlanningWindow,
        'priority-newer': PersonContextRelevanceBasis.typedActivePlanningWindow,
      },
      now: now,
      noContextBaseline: const <PersonContextBehaviorField, Object?>{},
    );
    expect(sameFieldConflict.used.single.signalId, 'priority-newer');
    expect(
      sameFieldConflict.rejected.single.rejectionReason,
      PersonContextRejectionReason.supersededByHigherAuthority,
    );
  });

  test(
    'consumer limits reject overflow instead of overstating behavior use',
    () {
      const List<PersonContextKind> inputOrder = <PersonContextKind>[
        PersonContextKind.preferredSupportStyle,
        PersonContextKind.currentPriority,
        PersonContextKind.presentCapacity,
        PersonContextKind.commitment,
        PersonContextKind.boundary,
      ];
      final PersonContextBehaviorTrace trace =
          PersonContextBehaviorPolicy.evaluate(
            signals: inputOrder
                .map((PersonContextKind kind) => _signalFor(kind, now: now))
                .toList(growable: false),
            surface: PersonContextSurface.smartPlanner,
            purposes: const <PersonContextPurpose>{
              PersonContextPurpose.planningGuidance,
              PersonContextPurpose.decisionSupport,
            },
            relevance: <String, PersonContextRelevanceBasis>{
              for (final PersonContextKind kind in inputOrder)
                'signal-${kind.name}': _basisFor(
                  PersonContextBehaviorPolicy.ruleFor(kind).relevanceRule,
                ),
            },
            now: now,
            noContextBaseline: const <PersonContextBehaviorField, Object?>{},
            maxUsedSignals: 3,
          );

      expect(
        trace.used.map((PersonContextBehaviorDecision value) => value.kind),
        <PersonContextKind>[
          PersonContextKind.boundary,
          PersonContextKind.commitment,
          PersonContextKind.presentCapacity,
        ],
      );
      expect(
        trace.rejected.map(
          (PersonContextBehaviorDecision value) => value.rejectionReason,
        ),
        everyElement(PersonContextRejectionReason.consumerLimitExceeded),
      );
      expect(
        trace.rejected.map(
          (PersonContextBehaviorDecision value) => value.effectSize,
        ),
        everyElement(PersonContextEffectSize.none),
      );
    },
  );

  test('trace snapshot is deterministic and omits raw context', () {
    final PersonContextBehaviorTrace evaluated =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[
            _signalFor(
              PersonContextKind.currentPriority,
              id: 'priority',
              now: now,
            ),
            _signalFor(PersonContextKind.boundary, id: 'boundary', now: now),
          ],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.decisionSupport,
            PersonContextPurpose.planningGuidance,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'priority': PersonContextRelevanceBasis.typedActivePlanningWindow,
            'boundary': PersonContextRelevanceBasis.typedExplicitBoundary,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{
            PersonContextBehaviorField.responseWording: 'neutral',
            PersonContextBehaviorField.rankingPriority: 'default',
          },
        );
    final PersonContextBehaviorTrace trace = PersonContextBehaviorPolicy.apply(
      trace: evaluated,
      effects: const <PersonContextBehaviorEffect>[
        PersonContextBehaviorEffect(
          signalId: 'boundary',
          field: PersonContextBehaviorField.hardBoundary,
          value: 'blocked',
        ),
        PersonContextBehaviorEffect(
          signalId: 'priority',
          field: PersonContextBehaviorField.rankingPriority,
          value: 'priority',
        ),
      ],
    ).trace;

    expect(trace.toJson(), <String, Object?>{
      'surface': 'smartPlanner',
      'purposes': <String>['planningGuidance', 'decisionSupport'],
      'observedAt': '2026-09-02T12:00:00.000Z',
      'noContextBaseline': <String, Object?>{
        'rankingPriority': 'default',
        'responseWording': 'neutral',
      },
      'used': <Map<String, Object?>>[
        <String, Object?>{
          'signalId': 'boundary',
          'kind': 'boundary',
          'status': 'used',
          'permittedField': 'hardBoundary',
          'effectSize': 'constraint',
          'conflictAuthority': 'boundary',
          'overrideBehavior': 'hardBoundary',
          'relevanceRule': 'explicitBoundary',
          'reason': 'typedExplicitBoundary',
        },
        <String, Object?>{
          'signalId': 'priority',
          'kind': 'currentPriority',
          'status': 'used',
          'permittedField': 'rankingPriority',
          'effectSize': 'tieBreak',
          'conflictAuthority': 'currentPriority',
          'overrideBehavior': 'tieBreakOnly',
          'relevanceRule': 'activePlanningWindow',
          'reason': 'typedActivePlanningWindow',
        },
      ],
      'rejected': <Map<String, Object?>>[],
      'appliedDelta': <Map<String, Object?>>[
        <String, Object?>{
          'signalId': 'boundary',
          'field': 'hardBoundary',
          'effectSize': 'constraint',
          'conflictAuthority': 'boundary',
          'beforeDigest': evidenceContentDigest(null),
          'afterDigest': evidenceContentDigest('blocked'),
          'changed': true,
        },
        <String, Object?>{
          'signalId': 'priority',
          'field': 'rankingPriority',
          'effectSize': 'tieBreak',
          'conflictAuthority': 'currentPriority',
          'beforeDigest': evidenceContentDigest('default'),
          'afterDigest': evidenceContentDigest('priority'),
          'changed': true,
        },
      ],
    });
    final String encoded = jsonEncode(trace.toJson());
    expect(encoded, isNot(contains('Exact context')));
    expect(jsonEncode(trace.toJson()), encoded);
  });

  test('a signal cannot apply outside its permitted field', () {
    final PersonContextSignal priority = _signalFor(
      PersonContextKind.currentPriority,
      id: 'priority',
      now: now,
    );
    final PersonContextBehaviorTrace trace =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[priority],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.decisionSupport,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'priority': PersonContextRelevanceBasis.exactTextMatch,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{
            PersonContextBehaviorField.rankingPriority: 'default',
            PersonContextBehaviorField.hardBoundary: 'none',
          },
        );

    expect(
      () => PersonContextBehaviorPolicy.apply(
        trace: trace,
        effects: const <PersonContextBehaviorEffect>[
          PersonContextBehaviorEffect(
            signalId: 'priority',
            field: PersonContextBehaviorField.hardBoundary,
            value: 'overreach',
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test('plain-language low capacity becomes a bounded 25-minute limit', () {
    final PersonContextSignal capacity = _signalFor(
      PersonContextKind.presentCapacity,
      id: 'capacity-low',
      value: 'Low energy today',
      now: now,
      surface: PersonContextSurface.smartPlanner,
    );
    final GovernedDecisionContext context = GovernedDecisionContext.resolve(
      view: PersonContextView(
        accountScopeId: 'account:test',
        surface: PersonContextSurface.smartPlanner,
        purposes: operationalPersonContextPurposes,
        observedAt: now,
        signals: <PersonContextSignal>[capacity],
        unknownKinds: const <PersonContextKind>{},
      ),
      accountScopeId: 'account:test',
      tasks: const <TaskEntity>[],
      now: now,
      surface: PersonContextSurface.smartPlanner,
    );

    expect(context.hasAppliedBehavior, isTrue);
    expect(context.capacityCapMinutes, 25);
  });

  test(
    'evaluated trace exposes approved fields before effects are applied',
    () {
      final PersonContextSignal priority = _signalFor(
        PersonContextKind.currentPriority,
        id: 'priority',
        now: now,
      );
      final PersonContextBehaviorTrace trace =
          PersonContextBehaviorPolicy.evaluate(
            signals: <PersonContextSignal>[priority],
            surface: PersonContextSurface.smartPlanner,
            purposes: const <PersonContextPurpose>{
              PersonContextPurpose.decisionSupport,
            },
            relevance: const <String, PersonContextRelevanceBasis>{
              'priority': PersonContextRelevanceBasis.typedActivePlanningWindow,
            },
            now: now,
            noContextBaseline: const <PersonContextBehaviorField, Object?>{},
          );

      expect(trace.changedFields, const <PersonContextBehaviorField>{
        PersonContextBehaviorField.rankingPriority,
      });
    },
  );

  test('invalid evaluation boundaries fail before context is consumed', () {
    PersonContextBehaviorTrace evaluate({
      Set<PersonContextPurpose> purposes = const <PersonContextPurpose>{
        PersonContextPurpose.decisionSupport,
      },
      int? maxUsedSignals,
    }) => PersonContextBehaviorPolicy.evaluate(
      signals: const <PersonContextSignal>[],
      surface: PersonContextSurface.smartPlanner,
      purposes: purposes,
      relevance: const <String, PersonContextRelevanceBasis>{},
      now: now,
      noContextBaseline: const <PersonContextBehaviorField, Object?>{},
      maxUsedSignals: maxUsedSignals,
    );

    expect(
      () => evaluate(purposes: const <PersonContextPurpose>{}),
      throwsArgumentError,
    );
    expect(() => evaluate(maxUsedSignals: -1), throwsArgumentError);
  });

  test('unknown and duplicate behavior effects fail closed', () {
    final PersonContextBehaviorTrace emptyTrace =
        PersonContextBehaviorPolicy.evaluate(
          signals: const <PersonContextSignal>[],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.decisionSupport,
          },
          relevance: const <String, PersonContextRelevanceBasis>{},
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );
    expect(
      () => PersonContextBehaviorPolicy.apply(
        trace: emptyTrace,
        effects: const <PersonContextBehaviorEffect>[
          PersonContextBehaviorEffect(
            signalId: 'unknown',
            field: PersonContextBehaviorField.rankingPriority,
            value: 'overreach',
          ),
        ],
      ),
      throwsStateError,
    );

    final PersonContextSignal priority = _signalFor(
      PersonContextKind.currentPriority,
      id: 'priority',
      now: now,
    );
    final PersonContextBehaviorTrace usedTrace =
        PersonContextBehaviorPolicy.evaluate(
          signals: <PersonContextSignal>[priority],
          surface: PersonContextSurface.smartPlanner,
          purposes: const <PersonContextPurpose>{
            PersonContextPurpose.decisionSupport,
          },
          relevance: const <String, PersonContextRelevanceBasis>{
            'priority': PersonContextRelevanceBasis.typedActivePlanningWindow,
          },
          now: now,
          noContextBaseline: const <PersonContextBehaviorField, Object?>{},
        );
    expect(
      () => PersonContextBehaviorPolicy.apply(
        trace: usedTrace,
        effects: const <PersonContextBehaviorEffect>[
          PersonContextBehaviorEffect(
            signalId: 'priority',
            field: PersonContextBehaviorField.rankingPriority,
            value: 'first',
          ),
          PersonContextBehaviorEffect(
            signalId: 'priority',
            field: PersonContextBehaviorField.rankingPriority,
            value: 'second',
          ),
        ],
      ),
      throwsStateError,
    );
  });

  test(
    'correction and withdrawal propagate through every Priority 4 surface',
    () {
      const String account = 'account:test';
      const List<PersonContextSurface> surfaces = <PersonContextSurface>[
        PersonContextSurface.siConsole,
        PersonContextSurface.trajectory,
        PersonContextSurface.creator,
      ];
      for (final PersonContextSurface surface in surfaces) {
        PersonContextView view(PersonContextSignal signal) => PersonContextView(
          accountScopeId: account,
          surface: surface,
          purposes: operationalPersonContextPurposes,
          observedAt: now,
          signals: <PersonContextSignal>[signal],
          unknownKinds: const <PersonContextKind>{},
        );
        PersonContextSignal capacity(String value, {bool withdrawn = false}) =>
            _signalFor(
              PersonContextKind.presentCapacity,
              id: 'shared-capacity',
              value: value,
              now: now,
              surface: surface,
              withdrawn: withdrawn,
            );
        GovernedDecisionContext resolve(PersonContextSignal signal) =>
            GovernedDecisionContext.resolve(
              view: view(signal),
              accountScopeId: account,
              tasks: <TaskEntity>[
                TaskEntity(id: 'task', title: 'Release evidence'),
              ],
              now: now,
              surface: surface,
            );

        final GovernedDecisionContext before = resolve(
          capacity('30 minutes available today'),
        );
        final GovernedDecisionContext afterCorrection = resolve(
          capacity('10 minutes available today'),
        );
        final GovernedDecisionContext afterWithdrawal = resolve(
          capacity('10 minutes available today', withdrawn: true),
        );
        expect(before.capacityCapMinutes, 30, reason: surface.name);
        expect(afterCorrection.capacityCapMinutes, 10, reason: surface.name);
        expect(
          afterCorrection.revision,
          isNot(before.revision),
          reason: surface.name,
        );
        expect(afterCorrection.trace!.toJson()['surface'], surface.name);
        expect(
          afterWithdrawal.hasAppliedBehavior,
          isFalse,
          reason: surface.name,
        );
        expect(afterWithdrawal.appliedSignalIds, isEmpty, reason: surface.name);
      }
    },
  );
}

const Set<PersonContextSurface> _allOperationalSurfaces =
    <PersonContextSurface>{
      PersonContextSurface.smartPlanner,
      PersonContextSurface.siConsole,
      PersonContextSurface.nexus,
      PersonContextSurface.trajectory,
      PersonContextSurface.creator,
    };

const Set<PersonContextSurface> _outcomeSurfaces = <PersonContextSurface>{
  PersonContextSurface.nexus,
  PersonContextSurface.trajectory,
};

const Map<PersonContextKind, _ExpectedRule> _expectedRules =
    <PersonContextKind, _ExpectedRule>{
      PersonContextKind.role: _ExpectedRule(
        purpose: PersonContextPurpose.decisionSupport,
        relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
        maxFreshness: Duration(days: 180),
        permittedField: PersonContextBehaviorField.supportingEvidence,
        effectSize: PersonContextEffectSize.evidenceOnly,
        conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
        overrideBehavior: PersonContextOverrideBehavior.evidenceOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.value: _ExpectedRule(
        purpose: PersonContextPurpose.decisionSupport,
        relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
        maxFreshness: Duration(days: 180),
        permittedField: PersonContextBehaviorField.supportingEvidence,
        effectSize: PersonContextEffectSize.evidenceOnly,
        conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
        overrideBehavior: PersonContextOverrideBehavior.evidenceOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.currentPriority: _ExpectedRule(
        purpose: PersonContextPurpose.decisionSupport,
        relevanceRule: PersonContextRelevanceRule.activePlanningWindow,
        maxFreshness: Duration(days: 30),
        permittedField: PersonContextBehaviorField.rankingPriority,
        effectSize: PersonContextEffectSize.tieBreak,
        conflictAuthority: PersonContextConflictAuthority.currentPriority,
        overrideBehavior: PersonContextOverrideBehavior.tieBreakOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.lifeArea: _ExpectedRule(
        purpose: PersonContextPurpose.decisionSupport,
        relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
        maxFreshness: Duration(days: 180),
        permittedField: PersonContextBehaviorField.planningScope,
        effectSize: PersonContextEffectSize.boundedAdjustment,
        conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
        overrideBehavior: PersonContextOverrideBehavior.scopeOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.presentCapacity: _ExpectedRule(
        purpose: PersonContextPurpose.decisionSupport,
        relevanceRule: PersonContextRelevanceRule.activePlanningWindow,
        maxFreshness: Duration(hours: 24),
        permittedField: PersonContextBehaviorField.capacityLimit,
        effectSize: PersonContextEffectSize.boundedAdjustment,
        conflictAuthority: PersonContextConflictAuthority.freshCapacity,
        overrideBehavior: PersonContextOverrideBehavior.reduceOrRescopeOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.preferredSupportStyle: _ExpectedRule(
        purpose: PersonContextPurpose.planningGuidance,
        relevanceRule: PersonContextRelevanceRule.responsePresentation,
        maxFreshness: Duration(days: 180),
        permittedField: PersonContextBehaviorField.responseWording,
        effectSize: PersonContextEffectSize.presentationOnly,
        conflictAuthority: PersonContextConflictAuthority.preferenceOrWording,
        overrideBehavior: PersonContextOverrideBehavior.wordingOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.boundary: _ExpectedRule(
        purpose: PersonContextPurpose.planningGuidance,
        relevanceRule: PersonContextRelevanceRule.explicitBoundary,
        maxFreshness: Duration(days: 180),
        permittedField: PersonContextBehaviorField.hardBoundary,
        effectSize: PersonContextEffectSize.constraint,
        conflictAuthority: PersonContextConflictAuthority.boundary,
        overrideBehavior: PersonContextOverrideBehavior.hardBoundary,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.importantRelationship: _ExpectedRule(
        purpose: PersonContextPurpose.planningGuidance,
        relevanceRule: PersonContextRelevanceRule.exactDecisionSubject,
        maxFreshness: Duration(days: 180),
        permittedField: PersonContextBehaviorField.supportingEvidence,
        effectSize: PersonContextEffectSize.evidenceOnly,
        conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
        overrideBehavior: PersonContextOverrideBehavior.evidenceOnly,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.commitment: _ExpectedRule(
        purpose: PersonContextPurpose.decisionSupport,
        relevanceRule: PersonContextRelevanceRule.explicitCommitment,
        maxFreshness: Duration(days: 30),
        permittedField: PersonContextBehaviorField.scheduledCommitment,
        effectSize: PersonContextEffectSize.constraint,
        conflictAuthority: PersonContextConflictAuthority.scheduledCommitment,
        overrideBehavior: PersonContextOverrideBehavior.scheduleConstraint,
        allowedSurfaces: _allOperationalSurfaces,
      ),
      PersonContextKind.outcomeHistory: _ExpectedRule(
        purpose: PersonContextPurpose.outcomeLearning,
        relevanceRule: PersonContextRelevanceRule.confirmedOutcome,
        maxFreshness: Duration(days: 90),
        permittedField: PersonContextBehaviorField.outcomeCalibration,
        effectSize: PersonContextEffectSize.boundedAdjustment,
        conflictAuthority: PersonContextConflictAuthority.evidenceOnly,
        overrideBehavior: PersonContextOverrideBehavior.calibrationOnly,
        allowedSurfaces: _outcomeSurfaces,
      ),
    };

final class _ExpectedRule {
  const _ExpectedRule({
    required this.purpose,
    required this.relevanceRule,
    required this.maxFreshness,
    required this.permittedField,
    required this.effectSize,
    required this.conflictAuthority,
    required this.overrideBehavior,
    required this.allowedSurfaces,
  });

  final PersonContextPurpose purpose;
  final PersonContextRelevanceRule relevanceRule;
  final Duration maxFreshness;
  final PersonContextBehaviorField permittedField;
  final PersonContextEffectSize effectSize;
  final PersonContextConflictAuthority conflictAuthority;
  final PersonContextOverrideBehavior overrideBehavior;
  final Set<PersonContextSurface> allowedSurfaces;
}

PersonContextRelevanceBasis _basisFor(PersonContextRelevanceRule rule) =>
    switch (rule) {
      PersonContextRelevanceRule.exactDecisionSubject =>
        PersonContextRelevanceBasis.exactTextMatch,
      PersonContextRelevanceRule.activePlanningWindow =>
        PersonContextRelevanceBasis.typedActivePlanningWindow,
      PersonContextRelevanceRule.responsePresentation =>
        PersonContextRelevanceBasis.typedResponsePresentation,
      PersonContextRelevanceRule.explicitBoundary =>
        PersonContextRelevanceBasis.typedExplicitBoundary,
      PersonContextRelevanceRule.explicitCommitment =>
        PersonContextRelevanceBasis.typedExplicitCommitment,
      PersonContextRelevanceRule.confirmedOutcome =>
        PersonContextRelevanceBasis.typedConfirmedOutcome,
    };

PersonContextSignal _signalFor(
  PersonContextKind kind, {
  required DateTime now,
  String? id,
  PersonContextSurface? surface,
  PersonContextPurpose? purpose,
  PersonContextSource? source,
  Duration? freshness,
  bool stale = false,
  bool withdrawn = false,
  String? value,
}) {
  final PersonContextBehaviorRule rule = PersonContextBehaviorPolicy.ruleFor(
    kind,
  );
  final DateTime recordedAt = now.subtract(const Duration(hours: 1));
  final DateTime freshUntil = stale
      ? now
      : recordedAt.add(freshness ?? rule.maxFreshness);
  final PersonContextSurface selectedSurface =
      surface ?? rule.allowedSurfaces.first;
  return PersonContextSignal(
    id: id ?? 'signal-${kind.name}',
    kind: kind,
    value: value ?? 'Exact context for ${kind.name}',
    source:
        source ??
        (kind == PersonContextKind.outcomeHistory
            ? PersonContextSource.confirmedOutcome
            : PersonContextSource.userAuthored),
    consent: withdrawn
        ? PersonContextConsent.withdrawn
        : PersonContextConsent.granted,
    consentedAt: recordedAt,
    withdrawnAt: withdrawn ? recordedAt.add(const Duration(minutes: 30)) : null,
    purpose: purpose ?? rule.purpose,
    surfaceScopes: <PersonContextSurface>{selectedSurface},
    recordedAt: recordedAt,
    freshUntil: freshUntil,
    expiresAt: freshUntil.add(const Duration(days: 1)),
    exportBehavior: PersonContextExportBehavior.include,
    deletionBehavior: kind == PersonContextKind.presentCapacity
        ? PersonContextDeletionBehavior.expiresAutomatically
        : PersonContextDeletionBehavior.userRemovable,
  );
}
