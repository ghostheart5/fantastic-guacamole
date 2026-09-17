import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/internal_credit_test_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Uses the existing private, authenticated AI cohort. Public launch remains
// contained until the new conversational experience is reviewed on-device.
final assistantConversationAvailableProvider = Provider<bool>(
  (ref) => ref.watch(internalCreditTestEnabledProvider),
);

final conversationTransportProvider = Provider<ConversationTransport>(
  (ref) => ref.watch(internalCreditTestTransportProvider),
);

final conversationServiceProvider = Provider<ConversationService>((ref) {
  final account = ref.watch(accountStorageScopeProvider).v2Namespace;
  final generation = ref.watch(authSessionBoundaryProvider).generation;
  return ConversationService(
    transport: ref.watch(conversationTransportProvider),
    authorize: (packet) {
      if (!ref.mounted ||
          !ref.read(assistantConversationAvailableProvider) ||
          !ref.read(personalizationProfileProvider).externalAiAllowed ||
          ref.read(authSessionBoundaryProvider).isTransitioning ||
          !ref.read(authSessionBoundaryProvider).isStorageReady ||
          packet.accountScope != account ||
          ref.read(accountStorageScopeProvider).v2Namespace != account ||
          ref.read(authSessionBoundaryProvider).generation != generation) {
        throw const ConversationFailure('authorization_changed');
      }
      final capability = packet.surface == ConversationSurface.planner
          ? AssistantReleaseCapability.smartPlannerV2
          : AssistantReleaseCapability.siConsoleV2;
      for (final flag in [
        capability,
        AssistantReleaseCapability.safetyCritic,
      ]) {
        if (ref
                .read(assistantReleaseDecisionProvider(flag))
                .asData
                ?.value
                .enabled !=
            true) {
          throw const ConversationFailure('release_unavailable');
        }
      }
      final body = packet.toJson();
      final packetContext = Map<String, dynamic>.from(body['context'] as Map);
      if (packetContext['reportedEmotion'] != null &&
          !ref.read(consentedHumanContextProvider).emotionAllowed) {
        throw const ConversationFailure('authorization_changed');
      }
      final selectedNoteId = packetContext['selectedNoteId'];
      if (selectedNoteId != null &&
          ref.read(selectedPlanningNoteProvider).asData?.value?.id !=
              selectedNoteId) {
        throw const ConversationFailure('authorization_changed');
      }
      final text = [
        body['prompt'],
        ...(body['history'] as List)
            .whereType<Map<String, dynamic>>()
            .where((turn) => turn['role'] == 'user')
            .map((turn) => turn['content']),
      ].join(' ');
      if (EmotionalSafetyPolicy.assess(text).route !=
          EmotionalSafetyRoute.routine) {
        throw const ConversationFailure('supportive_route_required');
      }
    },
  );
});

final conversationPacketFactoryProvider = Provider<ConversationPacketFactory>(
  (ref) => ConversationPacketFactory(ref),
);

final class ConversationPacketFactory {
  ConversationPacketFactory(this.ref);
  final Ref ref;

  Future<ConversationPacket> build({
    required ConversationSurface surface,
    required String prompt,
    required List<Map<String, String>> history,
    required String languageCode,
    SIV2Intent intent = SIV2Intent.answer,
    Set<SIV2Source> sources = const {
      SIV2Source.tasks,
      SIV2Source.goals,
      SIV2Source.milestones,
      SIV2Source.timeline,
    },
    SIV2TimeRange range = SIV2TimeRange.all,
    String entityFilter = '',
    String scenario = '',
    double? reportedEnergy,
    String? selectedTaskId,
    bool attachedTaskOnly = false,
  }) async {
    final taskOnly =
        surface == ConversationSurface.planner &&
        selectedTaskId != null &&
        attachedTaskOnly;
    final scope = ref.read(accountStorageScopeProvider).v2Namespace;
    final generation = ref.read(authSessionBoundaryProvider).generation;
    if (scope == null ||
        ref.read(authSessionBoundaryProvider).isTransitioning ||
        !ref.read(authSessionBoundaryProvider).isStorageReady) {
      throw const ConversationFailure('authentication_required');
    }
    final now = DateTime.now();
    for (final flag in [
      surface == ConversationSurface.planner
          ? AssistantReleaseCapability.smartPlannerV2
          : AssistantReleaseCapability.siConsoleV2,
      AssistantReleaseCapability.safetyCritic,
    ]) {
      if (!(await ref.read(
        assistantReleaseDecisionProvider(flag).future,
      )).enabled) {
        throw const ConversationFailure('release_unavailable');
      }
    }
    final snapshot = await ref
        .read(siV2ReadGatewayProvider)
        .read(observedAt: now.toUtc(), decisionText: prompt);
    final note = surface == ConversationSurface.planner && !taskOnly
        ? await ref.read(selectedPlanningNoteProvider.future)
        : null;
    if (!ref.mounted ||
        snapshot.accountScopeId != scope ||
        scope != ref.read(accountStorageScopeProvider).v2Namespace ||
        generation != ref.read(authSessionBoundaryProvider).generation) {
      throw const ConversationFailure('authorization_changed');
    }
    final human = ref.read(consentedHumanContextProvider);
    final query = SIV2Query.fromUserInput(
      rawText: prompt,
      selectedIntent: intent,
      selectedSources: sources,
      timeRange: range,
      entityFilter: entityFilter,
      scenarioAssumption: scenario,
    );
    // Reuse the local engine's source, date and entity lens. Only its selected
    // evidence is sent, never its generic answer as a substitute for reasoning.
    final local = const SIV2Engine().analyze(
      query: query,
      snapshot: snapshot,
      now: now,
    );
    final ids = local.evidenceLinks.map((link) => link.evidenceId).toSet();
    final tasks = snapshot.tasks
        .where(
          (t) =>
              taskOnly ? t.id == selectedTaskId : ids.contains('tasks:${t.id}'),
        )
        .toList();
    // Descriptions are optional enrichment. An unavailable task repository must
    // not prevent a question about other sources or discard existing evidence.
    List<TaskEntity> taskDetails = const [];
    var taskDetailsUnavailable = false;
    if (tasks.isNotEmpty) {
      try {
        taskDetails = await ref
            .read(domainTaskRepositoryProvider)
            .getAllTasks()
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        taskDetailsUnavailable = true;
      }
      if (!ref.mounted ||
          scope != ref.read(accountStorageScopeProvider).v2Namespace ||
          generation != ref.read(authSessionBoundaryProvider).generation) {
        throw const ConversationFailure('authorization_changed');
      }
    }
    // An explicit attachment takes precedence over broad record ranking. Other
    // records stay available for conflicts, subject to the same selected lens.
    final attachedId = selectedTaskId ?? note?.taskId;
    if (selectedTaskId != null && !tasks.any((t) => t.id == selectedTaskId)) {
      throw const ConversationFailure('attachment_unavailable');
    }
    final topic = RegExp(
      r'[a-záéíóúñ]{3,}',
      caseSensitive: false,
    ).allMatches(prompt.toLowerCase()).map((m) => m.group(0)!).toSet();
    int relevance(SIV2TaskEvidence task) => task.id == attachedId
        ? 10000
        : topic.where((term) => task.title.toLowerCase().contains(term)).length;
    tasks.sort((a, b) => relevance(b).compareTo(relevance(a)));
    final goals = snapshot.goals
        .where((g) => !taskOnly && ids.contains('goals:${g.id}'))
        .toList();
    final milestones = snapshot.milestones
        .where((m) => !taskOnly && ids.contains('milestones:${m.id}'))
        .toList();
    final timeline = snapshot.timeline
        .where((t) => !taskOnly && ids.contains('timeline:${t.id}'))
        .toList();
    String bounded(String text, int limit) =>
        text.length > limit ? '${text.substring(0, limit)} [truncated]' : text;
    String? localDate(DateTime? time) => time?.toLocal().toIso8601String();
    return ConversationPacket(
      surface: surface,
      accountScope: scope,
      prompt: prompt,
      history: history,
      context: {
        'language': languageCode,
        'nowLocal': now.toIso8601String(),
        'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
        'mode': query.intent.name,
        'timeRange': range.name,
        'entityFilter': entityFilter,
        'scenarioAssumption': scenario,
        'evidenceRevision': snapshot.revision,
        if (taskOnly) 'contextScope': 'attachedTaskOnly',
        if (taskDetailsUnavailable) 'taskDetailsUnavailable': true,
        'explicitlyAttachedTaskId': ?attachedId,
        'tasks': tasks
            .take(12)
            .map(
              (t) => {
                'id': t.id,
                'title': bounded(t.title, 240),
                'priority': t.priority,
                'scheduledStart': localDate(t.scheduledFor),
                'deadline': localDate(t.dueDate),
                'goalId': t.goalId,
                'description': bounded(
                  taskDetails
                          .where((item) => item.id == t.id)
                          .firstOrNull
                          ?.description ??
                      '',
                  500,
                ),
                'estimatedDurationMinutes': taskDetails
                    .where((item) => item.id == t.id)
                    .firstOrNull
                    ?.estimatedDuration
                    ?.inMinutes,
              },
            )
            .toList(),
        'goals': goals
            .take(12)
            .map(
              (g) => {
                'id': g.id,
                'title': bounded(g.title, 240),
                'targetDate': localDate(g.targetDate),
              },
            )
            .toList(),
        'milestones': milestones
            .take(12)
            .map(
              (m) => {
                'id': m.id,
                'title': bounded(m.title, 240),
                'goalId': m.goalId,
                'completionPercent': m.completionPercent,
                'targetDate': localDate(m.targetDate),
                'completed': m.completed,
              },
            )
            .toList(),
        'timeline': timeline
            .take(12)
            .map(
              (t) => {
                'title': bounded(t.title, 240),
                'timestamp': localDate(t.timestamp),
                'type': t.type,
                'status': t.status,
              },
            )
            .toList(),
        'omittedRecordCount': [
          tasks.length,
          goals.length,
          milestones.length,
          timeline.length,
        ].fold<int>(0, (sum, size) => sum + (size > 12 ? size - 12 : 0)),
        'unavailableSources': snapshot.unavailableSources
            .where((source) => !taskOnly || source == SIV2Source.tasks)
            .map((source) => source.name)
            .toList(),
        if (note != null) 'selectedNoteId': note.id,
        if (note != null)
          'explicitlyAttachedNote': {
            'title': bounded(note.title, 240),
            'body': bounded(note.body ?? '', 1800),
            'taskId': note.taskId,
            'goalId': note.goalId,
          },
        if (surface == ConversationSurface.planner)
          'reportedEnergy': human.authorizeReportedEnergy(reportedEnergy),
        if (surface == ConversationSurface.planner &&
            !taskOnly &&
            human.emotionAllowed &&
            human.emotion != null)
          'reportedEmotion': human.emotion!.name,
      },
    );
  }
}
