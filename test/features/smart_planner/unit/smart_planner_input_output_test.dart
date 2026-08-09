import 'package:fantastic_guacamole/domain/entities/completion_event_entity.dart';
import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/routine_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/engine/si/models/si_state.dart';

import 'package:fantastic_guacamole/state/controllers/coach_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/data/di/storage_providers.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/state/providers/completion_events_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/goals_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/routines_provider.dart';
import 'package:fantastic_guacamole/state/providers/task_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Smart Planner preserves task, habit, goal, and timeline context in planning output',
    () async {
      const String prompt = 'What should I focus on today?';
      final DateTime fixedNow = DateTime(2026, 8, 2, 9);

      final List<Task> tasks = <Task>[
        Task(
          id: 'task-1',
          title: 'Draft launch brief',
          priority: 5,
          difficulty: 3,
          energyRequired: 3,
          scheduledFor: fixedNow,
        ),
      ];

      final List<GoalEntity> goals = <GoalEntity>[
        GoalEntity(
          id: 'goal-1',
          title: 'Ship ChronoSpark beta',
          createdAt: fixedNow,
        ),
      ];

      final List<RoutineEntity> routines = <RoutineEntity>[
        RoutineEntity(
          id: 'habit-1',
          name: 'Daily review ritual',
          createdAt: fixedNow,
        ),
      ];

      final List<MemoryEntity> memories = <MemoryEntity>[
        MemoryEntity(
          id: 'memory-1',
          text: 'Keep launch prep visible before noon.',
          date: fixedNow,
          category: MemoryCategory.journal,
        ),
      ];

      final List<TimelineEventEntity> timeline = <TimelineEventEntity>[
        TimelineEventEntity(
          id: 'timeline-1',
          type: TimelineEventType.deadline,
          title: 'Beta rehearsal at 3 PM',
          detail: 'Prepare the launch demo flow.',
          timestamp: fixedNow,
          status: TimelineEventStatus.active,
          dueAt: fixedNow.add(const Duration(hours: 6)),
        ),
      ];

      final ProviderContainer container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(_InMemorySecureStore()),
          profileProvider.overrideWith(
            () => _StaticProfileController(
              ProfileState(
                name: 'Operator',
                level: 4,
                xp: 120,
                streak: 6,
                longestStreak: 9,
                profileReady: true,
              ),
            ),
          ),
          siStateProvider.overrideWith(
            () => _StaticSiStateController(
              const SIState(energy: 0.72, fatigue: 0.24, completedToday: 1),
            ),
          ),
          emotionProvider.overrideWith(() => _StaticEmotionNotifier()),
          tasksProvider.overrideWith((Ref ref) async => tasks),
          goalsProvider.overrideWith(() => _StaticGoalsNotifier(goals)),
          routinesProvider.overrideWith(
            () => _StaticRoutinesNotifier(routines),
          ),
          memoriesProvider.overrideWith(
            () => _StaticMemoriesNotifier(memories),
          ),
          timelineProvider.overrideWith(
            () => _StaticTimelineNotifier(timeline),
          ),
          completionEventsProvider.overrideWithValue(<CompletionEventEntity>[
            CompletionEventEntity(
              id: 'completion-1',
              eventType: CompletionEventType.completed,
              eventAt: fixedNow.subtract(const Duration(days: 1)),
              taskId: 'task-0',
            ),
          ]),
        ],
      );

      addTearDown(container.dispose);

      await container.read(tasksProvider.future);

      final CoachCoachingResult result = await container
          .read(coachQueryControllerProvider)
          .requestCoaching(
            energy: 0.72,
            emotion: EmotionalState.focused,
            notes: prompt,
            history: const <Map<String, String>>[],
            previousSavedNotes: prompt,
          );

      expect(result.message, isNotEmpty);
      expect(result.message, contains('Draft launch brief'));
      expect(result.message, contains('Daily review ritual'));
      expect(result.message, contains('Ship ChronoSpark beta'));
      expect(result.message, contains('Beta rehearsal at 3 PM'));
      expect(result.message.toLowerCase(), contains('next step'));
      expect(result.message, isNot(contains('no context available')));
    },
  );
}

class _StaticProfileController extends ProfileController {
  _StaticProfileController(this._state);

  final ProfileState _state;

  @override
  ProfileState build() => _state;

  @override
  void addXP(int amount) {
    state = state.copyWith(xp: state.xp + amount);
  }
}

class _StaticSiStateController extends SIStateController {
  _StaticSiStateController(this._state);

  final SIState _state;

  @override
  SIState build() => _state;
}

class _StaticEmotionNotifier extends EmotionNotifier {
  @override
  EmotionalState build() => EmotionalState.focused;
}

class _StaticGoalsNotifier extends GoalsNotifier {
  _StaticGoalsNotifier(this._goals);

  final List<GoalEntity> _goals;

  @override
  List<GoalEntity> build() => _goals;
}

class _StaticRoutinesNotifier extends RoutinesNotifier {
  _StaticRoutinesNotifier(this._routines);

  final List<RoutineEntity> _routines;

  @override
  List<RoutineEntity> build() => _routines;
}

class _StaticMemoriesNotifier extends MemoriesNotifier {
  _StaticMemoriesNotifier(this._memories);

  final List<MemoryEntity> _memories;

  @override
  List<MemoryEntity> build() => _memories;
}

class _StaticTimelineNotifier extends TimelineNotifier {
  _StaticTimelineNotifier(this._timeline);

  final List<TimelineEventEntity> _timeline;

  @override
  List<TimelineEventEntity> build() => _timeline;
}

class _InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> readString(String key) async {
    return _values[key];
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<bool?> readBool(String key) async {
    final String? value = _values[key];
    if (value == null) {
      return null;
    }

    if (value == 'true') {
      return true;
    }

    if (value == 'false') {
      return false;
    }

    return null;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value.toString();
  }

  @override
  Future<double?> readDouble(String key) async {
    final String? value = _values[key];
    if (value == null) {
      return null;
    }

    return double.tryParse(value);
  }

  @override
  Future<void> writeDouble(String key, double value) async {
    _values[key] = value.toString();
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}
