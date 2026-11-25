import 'dart:async';

import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/storage_providers.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A confirmed AI chat question finishes the Chat or Choose a step lesson,
/// once, for the account that sent it, without touching the paid request.
void main() {
  late String account;
  late int generation;
  late _RecordingGuidance guidance;

  ProviderContainer container() => ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(
        SecureStore(backend: InMemorySecureStoreBackend()),
      ),
      accountStorageScopeProvider.overrideWith(
        (ref) => AccountStorageScope.authenticated(account),
      ),
      authSessionBoundaryProvider.overrideWith(
        () => _Boundary(() => generation),
      ),
      conversationPurgeTimerProvider.overrideWithValue(
        (delay, callback) => _IdleTimer(),
      ),
      adaptiveGuidanceProvider.overrideWith(() => guidance),
    ],
  );

  ConversationQuote quote(ConversationSurface surface, String id) =>
      ConversationQuote(
        packet: ConversationPacket(
          surface: surface,
          accountScope: AccountStorageScope.authenticated(account).v2Namespace!,
          prompt: 'Question $id',
          history: const [],
          context: const {'language': 'en'},
          requestId: id,
        ),
        data: {
          'credits': 4,
          'digest': 'd',
          'proof': 'p',
          'policy': 'v',
          'expiresAt': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
        },
      );

  ({int status, Map<String, dynamic> data}) answer(String id) => (
    status: 200,
    data: <String, dynamic>{
      'requestId': id,
      'creditsCharged': 4,
      'remainingCredits': 10,
      'message': 'An answer.',
      'model': 'model-a',
    },
  );

  setUp(() {
    account = 'lesson-a';
    generation = 1;
    guidance = _RecordingGuidance();
  });

  for (final (ConversationSurface surface, GuidanceMilestone milestone)
      in <(ConversationSurface, GuidanceMilestone)>[
        (ConversationSurface.si, GuidanceMilestone.firstSiQuery),
        (ConversationSurface.planner, GuidanceMilestone.firstPlannerQuestion),
      ]) {
    test('an answered ${surface.name} send records its lesson once, '
        'even when a returning screen joins it', () async {
      final c = container();
      addTearDown(c.dispose);
      final reply = Completer<({int status, Map<String, dynamic> data})>();
      var sends = 0;
      final service = ConversationService(
        transport: (_) {
          sends++;
          return reply.future;
        },
        authorize: (_) {},
      );
      final registry = c.read(conversationExecutionRegistryProvider);
      final sent = quote(surface, 'req-1');
      final first = registry.execute(sent, service);
      final joined = registry.execute(sent, service);
      await pumpEventQueue();
      // Confirmed but not answered yet: nothing recorded.
      expect(guidance.recorded, isEmpty);
      reply.complete(answer('req-1'));
      expect((await first).text, 'An answer.');
      expect((await joined).text, 'An answer.');
      await pumpEventQueue();
      expect(sends, 1);
      expect(guidance.recorded, <GuidanceMilestone>[milestone]);
    });
  }

  test(
    'a failed send records nothing; its successful re-send records once',
    () async {
      final c = container();
      addTearDown(c.dispose);
      var attempt = 0;
      final service = ConversationService(
        transport: (_) async => ++attempt == 1
            ? (status: 503, data: <String, dynamic>{'error': 'busy'})
            : answer('req-2'),
        authorize: (_) {},
      );
      final registry = c.read(conversationExecutionRegistryProvider);
      final sent = quote(ConversationSurface.si, 'req-2');
      await expectLater(
        registry.execute(sent, service),
        throwsA(isA<ConversationFailure>()),
      );
      await pumpEventQueue();
      expect(guidance.recorded, isEmpty);
      expect((await registry.execute(sent, service)).text, 'An answer.');
      await pumpEventQueue();
      expect(guidance.recorded, <GuidanceMilestone>[
        GuidanceMilestone.firstSiQuery,
      ]);
    },
  );

  test('an answer arriving after an account change records nothing', () async {
    final c = container();
    addTearDown(c.dispose);
    final reply = Completer<({int status, Map<String, dynamic> data})>();
    final service = ConversationService(
      transport: (_) => reply.future,
      authorize: (_) {},
    );
    final pending = c
        .read(conversationExecutionRegistryProvider)
        .execute(quote(ConversationSurface.si, 'req-3'), service);
    account = 'lesson-b';
    generation = 2;
    c.invalidate(accountStorageScopeProvider);
    c.invalidate(authSessionBoundaryProvider);
    c.read(conversationExecutionRegistryProvider);
    reply.complete(answer('req-3'));
    await pending;
    await pumpEventQueue();
    expect(guidance.recorded, isEmpty);
  });

  test('a failing guidance write never affects the answer', () async {
    guidance = _RecordingGuidance(fail: true);
    final c = container();
    addTearDown(c.dispose);
    final service = ConversationService(
      transport: (_) async => answer('req-4'),
      authorize: (_) {},
    );
    final result = await c
        .read(conversationExecutionRegistryProvider)
        .execute(quote(ConversationSurface.planner, 'req-4'), service);
    await pumpEventQueue();
    expect(result.text, 'An answer.');
    expect(guidance.recorded, <GuidanceMilestone>[
      GuidanceMilestone.firstPlannerQuestion,
    ]);
  });
}

class _RecordingGuidance extends AdaptiveGuidanceNotifier {
  _RecordingGuidance({this.fail = false});

  final bool fail;
  final List<GuidanceMilestone> recorded = <GuidanceMilestone>[];

  @override
  Future<AdaptiveGuidanceState> build() async => const AdaptiveGuidanceState(
    milestones: <GuidanceMilestone, DateTime>{},
    counts: <GuidanceMilestone, int>{},
    skippedLessons: <GuidanceLessonId>{},
    completedLessons: <GuidanceLessonId>{},
  );

  @override
  Future<void> recordIfMissing(
    GuidanceMilestone milestone, {
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return;
    recorded.add(milestone);
    if (fail) throw StateError('storage unavailable');
  }
}

class _Boundary extends AuthSessionBoundaryNotifier {
  _Boundary(this._generation);
  final int Function() _generation;

  @override
  AuthSessionBoundary build() => AuthSessionBoundary(
    generation: _generation(),
    userId: 'lesson-user',
    isTransitioning: false,
    isStorageReady: true,
  );
}

final class _IdleTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}
