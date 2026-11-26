import 'dart:async';

import 'package:fantastic_guacamole/data/repositories/assistant_conversation_repository.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/conversation_extra_sources.dart';
import 'package:fantastic_guacamole/domain/assistant/axiomara_router_contract.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/engine/si/api.dart';
import 'package:fantastic_guacamole/engine/assistant/axiomara_deterministic_router.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/providers/ai_chat_extra_sources_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_extra_records.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/internal_credit_test_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

// Availability follows the reviewed public capabilities or existing private
// cohort through the shared providers. Consent and account generation are
// checked again before quoting and after paid execution.
final assistantConversationAvailableProvider = Provider<bool>(
  (ref) =>
      ref.watch(accountStorageScopeProvider).isWritable &&
      ref.watch(aiProxyAvailableProvider) &&
      ref.watch(creditSpendingAvailableProvider),
);

/// Advisory, on-device classification only. The paid conversation boundary
/// still requires its existing disclosure, quote and explicit confirmation.
final axiomaraRouterProvider = Provider<AxiomaraRouterPort>(
  (ref) => const AxiomaraDeterministicRouter(),
);

// Route selection also respects the surface cohort and safety rollback. Loading
// or failed release decisions retain the on-device UI until approval resolves.
final assistantConversationSurfaceAvailableProvider =
    Provider.family<bool, ConversationSurface>((ref, surface) {
      if (!ref.watch(assistantConversationAvailableProvider)) return false;
      final capability = surface == ConversationSurface.planner
          ? AssistantReleaseCapability.smartPlannerV2
          : AssistantReleaseCapability.siConsoleV2;
      return ref
                  .watch(assistantReleaseDecisionProvider(capability))
                  .asData
                  ?.value
                  .enabled ==
              true &&
          ref
                  .watch(
                    assistantReleaseDecisionProvider(
                      AssistantReleaseCapability.safetyCritic,
                    ),
                  )
                  .asData
                  ?.value
                  .enabled ==
              true;
    });

/// Why AI chat cannot be used right now, so the mode switch can say so in
/// plain words instead of hiding. [none] means it can be used.
enum AiChatBlock {
  none,
  accountNotReady,
  notAvailable,
  checking,
  notAvailableNow,
}

/// Whether this build has AI chat at all. Only a build without it hides the
/// mode switch; every other case shows the switch and explains when tapped.
final assistantChatInBuildProvider = Provider<bool>(
  (ref) =>
      ref.watch(externalAiAvailableProvider) ||
      ref.watch(assistantConversationAvailableProvider),
);

final assistantChatBlockProvider =
    Provider.family<AiChatBlock, ConversationSurface>((ref, surface) {
      if (!ref.watch(accountStorageScopeProvider).isWritable) {
        return AiChatBlock.accountNotReady;
      }
      if (!ref.watch(assistantConversationAvailableProvider)) {
        return AiChatBlock.notAvailable;
      }
      final capability = surface == ConversationSurface.planner
          ? AssistantReleaseCapability.smartPlannerV2
          : AssistantReleaseCapability.siConsoleV2;
      final decisions = [
        ref.watch(assistantReleaseDecisionProvider(capability)),
        ref.watch(
          assistantReleaseDecisionProvider(
            AssistantReleaseCapability.safetyCritic,
          ),
        ),
      ];
      if (decisions.any(
        (d) => d.hasError || d.asData?.value.enabled == false,
      )) {
        return AiChatBlock.notAvailableNow;
      }
      if (decisions.any((d) => d.asData == null)) return AiChatBlock.checking;
      return AiChatBlock.none;
    });

final conversationTransportProvider = Provider<ConversationTransport>(
  (ref) => ref.watch(internalCreditTestTransportProvider),
);

/// A second, UI-facing deadline around quote requests.
///
/// Paid execution is deliberately not abandoned: its authoritative settlement
/// and reply continue after the person dismisses the wait indicator.
final conversationRequestTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 40),
);

/// Releases the conversation UI if a paid transport never completes. The
/// original request keeps running so an authoritative late reply can appear.
final conversationPaidWaitTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 60),
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
      if (EmotionalSafetyPolicy.assess(
            '$text ${packet.attachedNoteSafetyText}',
          ).route !=
          EmotionalSafetyRoute.routine) {
        throw const ConversationFailure('supportive_route_required');
      }
    },
  );
});

/// How long a screen waits before collecting again a request whose first call
/// the server reports as still running (`request_reserved`).
final conversationReservedRetryIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 3),
);

/// Paid executions outlive the screen that confirmed them. Leaving Chat or
/// Choose a step disposes the screen, not this registry, so a returning screen
/// joins the running request instead of sending it again. A new account or
/// sign-in starts an empty registry; its stored request is then re-sent with
/// the same id. Once the first call has finished the server answers that from
/// its reply cache; while the first call is still running it answers
/// `request_reserved` without a second charge, and the screen keeps the
/// request and collects it again a few seconds later, until it can no longer
/// be collected.
typedef ConversationPurgeTimer =
    Timer Function(Duration delay, void Function() callback);

/// Creates the purge timer outside any fake-time zone (a widget test's fake
/// clock would otherwise report it as a leak when a test ends with a request
/// in flight). The callback runs back in the zone that armed it. Disposing
/// the registry cancels it.
final conversationPurgeTimerProvider = Provider<ConversationPurgeTimer>(
  (ref) => (delay, callback) {
    // Guarded: a synchronous throw reaches the arming zone's error handler.
    final guarded = Zone.current.bindCallbackGuarded(callback);
    return Zone.root.createTimer(delay, guarded);
  },
);

final conversationExecutionRegistryProvider =
    Provider<ConversationExecutionRegistry>((ref) {
      final account = ref.watch(
        accountStorageScopeProvider.select((s) => s.v2Namespace),
      );
      final generation = ref.watch(
        authSessionBoundaryProvider.select((b) => b.generation),
      );
      final registry = ConversationExecutionRegistry(
        createTimer: ref.read(conversationPurgeTimerProvider),
        // Read when the timer fires: the repository is rebuilt on every auth
        // event (a token refresh too), so a kept instance would go stale.
        readStore: () =>
            ref.read(assistantConversationHistoryRepositoryProvider),
        onAnswered: (packet) {
          // A confirmed question that was answered finishes the Chat or
          // Choose a step lesson, only for the account that sent it.
          bool sameAccount() =>
              ref.mounted &&
              account != null &&
              packet.accountScope == account &&
              ref.read(accountStorageScopeProvider).v2Namespace == account &&
              ref.read(authSessionBoundaryProvider).generation == generation;
          if (!sameAccount()) return;
          ref
              .read(adaptiveGuidanceProvider.notifier)
              .recordIfMissing(
                packet.surface == ConversationSurface.planner
                    ? GuidanceMilestone.firstPlannerQuestion
                    : GuidanceMilestone.firstSiQuery,
                shouldContinue: sameAccount,
              )
              .ignore();
        },
        onReleased: (requestId, {required failed, required completed}) {
          if (!ref.mounted) return;
          ref
              .read(aiCreditKnownBalanceProvider.notifier)
              .release(requestId, failed: failed, completed: completed);
        },
      );
      // An account or generation change drops this registry and its timer.
      ref.onDispose(registry.dispose);
      return registry;
    });

final class ConversationExecutionRegistry {
  ConversationExecutionRegistry({
    ConversationPurgeTimer? createTimer,
    AssistantConversationRepository? Function()? readStore,
    this.onAnswered,
    this.onReleased,
  }) : _createTimer = createTimer ?? Timer.new,
       _readStore = readStore ?? (() => null);

  final ConversationPurgeTimer _createTimer;
  final AssistantConversationRepository? Function() _readStore;

  /// Told when an execution completes (answer or failure, whoever is
  /// listening) and when a request's outcome is finished; it no longer
  /// counts as running for the AI credit balance. [failed] is true when the
  /// execution failed, which may have refunded its charge; [completed] when
  /// it answered, which settled it (only from the answer itself, never from
  /// [finish]).
  final void Function(
    String requestId, {
    required bool failed,
    required bool completed,
  })?
  onReleased;

  void _release(
    String requestId, {
    bool failed = false,
    bool completed = false,
  }) {
    if (_disposed) return;
    try {
      onReleased?.call(requestId, failed: failed, completed: completed);
    } on Object {
      // Display bookkeeping only.
    }
  }

  /// Told once per answered execution started here (a joined request is not
  /// a second answer). It can never change the request's own outcome.
  final void Function(ConversationPacket packet)? onAnswered;
  final _running =
      <String, ({Future<ConversationAnswer> future, bool failed})>{};
  final _shown = <String>{};
  Timer? _purgeTimer;
  DateTime? _purgeAt;
  bool _purgeWanted = false;
  bool _disposed = false;

  /// Removes a stored request's content once it can no longer be collected,
  /// while the app keeps running and no screen is open. One timer, armed for
  /// the earliest collect-by time; an earlier deadline replaces a later one.
  /// A request still running or holding an unshown reply here is never
  /// purged ([isRunning]). The current account's repository is read when
  /// the timer fires; this registry is dropped on any account change.
  void schedulePurge(DateTime at) {
    if (_disposed) return;
    _purgeWanted = true;
    final armed = _purgeAt;
    if (_purgeTimer?.isActive == true && armed != null && !at.isBefore(armed)) {
      return;
    }
    _purgeTimer?.cancel();
    _purgeAt = at;
    final delay = at.difference(DateTime.now().toUtc());
    _purgeTimer = _createTimer(
      // A second of margin so the expiry check sees the deadline as passed.
      (delay.isNegative ? Duration.zero : delay) + const Duration(seconds: 1),
      () => unawaited(_runPurge()),
    );
  }

  Future<void> _runPurge() async {
    _purgeTimer = null;
    _purgeAt = null;
    if (_disposed) return;
    try {
      final store = _readStore();
      if (store == null) return;
      final next = await store.purgeExpiredPending(keep: isRunning);
      if (next != null) schedulePurge(next);
    } on Object {
      // Account changed or storage failed: the next load or account opening
      // purges instead.
    }
  }

  void dispose() {
    _disposed = true;
    _purgeTimer?.cancel();
    _purgeTimer = null;
  }

  /// Joins the running execution of this request, or starts one. A failed
  /// attempt may be re-sent: the server never reserves the same id twice.
  Future<ConversationAnswer> execute(
    ConversationQuote quote,
    ConversationService service,
  ) {
    final id = quote.packet.requestId;
    final running = _running[id];
    if (running != null && !running.failed) return running.future;
    final future = service.execute(quote);
    _running[id] = (future: future, failed: false);
    // Also keeps an outcome nobody is waiting for from surfacing as an
    // unhandled error after its screen closed.
    unawaited(
      future.then<void>(
        (_) {
          if (_disposed) return;
          _release(id, completed: true);
          try {
            onAnswered?.call(quote.packet);
          } on Object {
            // Bookkeeping only: the answer already belongs to the person.
          }
        },
        onError: (Object _) {
          _release(id, failed: true);
          if (identical(_running[id]?.future, future)) {
            _running[id] = (future: future, failed: true);
            // A run kept past its deadline may now be purged.
            if (_purgeWanted) schedulePurge(DateTime.now().toUtc());
          }
        },
      ),
    );
    return future;
  }

  /// The request's outcome reached the person; it is never shown again.
  void finish(String requestId, {required bool shown}) {
    _running.remove(requestId);
    if (shown) _shown.add(requestId);
    _release(requestId);
  }

  bool wasShown(String requestId) => _shown.contains(requestId);

  /// Started in this session and not known to have failed.
  bool isRunning(String requestId) => _running[requestId]?.failed == false;
}

/// The information selection whose full preview the person has already
/// accepted, per surface, for this account while the app runs. Sending with
/// the same selection skips the automatic preview; a new app run, a new
/// account or session, or a changed selection shows it again. Kept in memory
/// only: nothing is stored.
final conversationPreviewMemoryProvider = Provider<ConversationPreviewMemory>((
  ref,
) {
  ref.watch(accountStorageScopeProvider.select((s) => s.v2Namespace));
  ref.watch(authSessionBoundaryProvider.select((b) => b.generation));
  return ConversationPreviewMemory();
});

final class ConversationPreviewMemory {
  final _accepted = <ConversationSurface, String>{};

  bool hasAccepted(ConversationSurface surface, String selection) =>
      _accepted[surface] == selection;

  void accept(ConversationSurface surface, String selection) =>
      _accepted[surface] = selection;
}

/// The moment a request is built. Tests replace it with a fixed time.
final conversationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

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
    Set<ConversationExtraSource> extraSources = const {},
  }) async {
    final taskOnly =
        surface == ConversationSurface.planner &&
        selectedTaskId != null &&
        attachedTaskOnly;
    // Extra information is a Chat choice on top of saved information: it is
    // ignored while the build switch is off, for Choose a step, for one
    // attached task and for Just this chat.
    final extras =
        surface == ConversationSurface.si &&
            !taskOnly &&
            sources.isNotEmpty &&
            ref.read(aiChatExtraSourcesAvailableProvider)
        ? extraSources
        : const <ConversationExtraSource>{};
    final scope = ref.read(accountStorageScopeProvider).v2Namespace;
    final generation = ref.read(authSessionBoundaryProvider).generation;
    if (scope == null ||
        ref.read(authSessionBoundaryProvider).isTransitioning ||
        !ref.read(authSessionBoundaryProvider).isStorageReady) {
      throw const ConversationFailure('authentication_required');
    }
    final now = ref.read(conversationClockProvider)();
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
        .read(
          observedAt: now.toUtc(),
          decisionText: prompt,
          includeActivity: extras.isNotEmpty,
          // Applied before the read's own limits, so a long list is not cut
          // before the person's filter.
          titleContains: extras.isNotEmpty ? entityFilter : '',
          // The count of what does not fit is then exact.
          withoutReadLimits: extras.isNotEmpty,
        );
    final note =
        surface == ConversationSurface.planner &&
            !taskOnly &&
            sources.isNotEmpty
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
    String? taskTimeZoneId;
    if (surface == ConversationSurface.si &&
        query.intent == SIV2Intent.findConflict) {
      try {
        final platformZoneId =
            (await FlutterTimezone.getLocalTimezone().timeout(
              const Duration(seconds: 2),
            )).identifier;
        final platformZone = tz.getLocation(platformZoneId);
        final localZone = tz.local;
        if (localZone.name == platformZone.name &&
            tz.TZDateTime.from(now, localZone).timeZoneOffset ==
                now.timeZoneOffset) {
          taskTimeZoneId = localZone.name;
        }
      } on Object {
        // Native zone lookup or startup configuration is unavailable. The
        // server will request task/date context before a paid calculation.
      }
    }
    final effectiveSources = taskOnly
        ? const <SIV2Source>{SIV2Source.tasks}
        : query.sources;
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
        : task.id == local.focusTaskId
        ? 9000
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
    final extra = ConversationExtraRecords.read(
      extras: extras,
      snapshot: snapshot,
      entityFilter: entityFilter,
      window: ConversationRecentWindow.forRange(range),
      now: now,
      title: (text) => bounded(text, conversationExtraTitleLimit),
    );
    return ConversationPacket(
      surface: surface,
      accountScope: scope,
      prompt: prompt,
      history: history,
      context: {
        'language': languageCode,
        'nowLocal': now.toIso8601String(),
        'utcOffsetMinutes': now.timeZoneOffset.inMinutes,
        'taskTimeZoneId': taskTimeZoneId,
        'mode': query.intent.name,
        'timeRange': range.name,
        'selectedSources': [
          ...effectiveSources.map((source) => source.name),
          ...extras.map((source) => source.name),
        ]..sort(),
        'entityFilter': entityFilter,
        'scenarioAssumption': scenario,
        'evidenceRevision': effectiveSources.isEmpty
            ? 'chat-only'
            : snapshot.revision,
        if (effectiveSources.isEmpty) 'contextScope': 'chatOnly',
        if (taskOnly) 'contextScope': 'attachedTaskOnly',
        if (taskDetailsUnavailable) 'taskDetailsUnavailable': true,
        'explicitlyAttachedTaskId': ?attachedId,
        'focusedTaskId': ?local.focusTaskId,
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
        ...extra.records,
        'omittedRecordCount':
            [
              tasks.length,
              goals.length,
              milestones.length,
              timeline.length,
            ].fold<int>(0, (sum, size) => sum + (size > 12 ? size - 12 : 0)) +
            extra.omitted,
        'unavailableSources': [
          ...snapshot.unavailableSources
              .where(effectiveSources.contains)
              .map((source) => source.name),
          ...extra.unavailable,
        ],
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
            effectiveSources.isNotEmpty &&
            !taskOnly &&
            human.emotionAllowed &&
            human.emotion != null)
          'reportedEmotion': human.emotion!.name,
      },
    );
  }
}
