import 'package:fantastic_guacamole/engine/assistant/assistant_interfaces.dart';
import 'package:fantastic_guacamole/engine/assistant/assistant_models.dart';

class DefaultAssistantIntentDetector implements AssistantIntentDetector {
  const DefaultAssistantIntentDetector();

  @override
  AssistantIntent detect({required String input, required String surface}) {
    final String normalized = input.toLowerCase();
    if (surface == 'smart_coach') {
      return _detectSmartCoachIntent(normalized);
    }
    if (surface == 'si_console') {
      return _detectConsoleIntent(normalized);
    }
    return AssistantIntent(
      label: 'general',
      confidence: 0.5,
      surface: surface,
      metadata: <String, dynamic>{'group': 'general'},
    );
  }

  AssistantIntent _detectSmartCoachIntent(String text) {
    AssistantIntent result = const AssistantIntent(
      label: 'general_chat',
      confidence: 0.52,
      surface: 'smart_coach',
      metadata: <String, dynamic>{'group': 'general'},
    );

    if (_hasAny(text, <String>[
      'weight gain',
      'gain weight',
      'put on weight',
      'bulk',
    ])) {
      result = _intent('weight_gain', 0.89, 'health', text);
    } else if (_hasAny(text, <String>[
      'weight loss',
      'lose weight',
      'fat loss',
      'cutting',
    ])) {
      result = _intent('weight_loss', 0.89, 'health', text);
    } else if (_hasAny(text, <String>[
      'nutrition',
      'diet',
      'meal',
      'food',
      'protein',
      'calorie',
    ])) {
      result = _intent('nutrition', 0.84, 'health', text);
    } else if (_hasAny(text, <String>[
      'hydrate',
      'hydration',
      'water',
      'dehydrated',
    ])) {
      result = _intent('hydration', 0.84, 'health', text);
    } else if (_hasAny(text, <String>[
      'exercise',
      'workout',
      'training',
      'gym',
      'run',
      'lift',
    ])) {
      result = _intent('exercise', 0.84, 'health', text);
    } else if (_hasAny(text, <String>['sleep', 'rest', 'bedtime', 'wake up'])) {
      result = _intent('sleep', 0.82, 'health', text);
    } else if (_hasAny(text, <String>['recover', 'recovery', 'soreness'])) {
      result = _intent('recovery', 0.82, 'health', text);
    } else if (_hasAny(text, <String>[
      'energy',
      'tired',
      'fatigue',
      'drained',
    ])) {
      result = _intent('energy', 0.81, 'health', text);
    } else if (_hasAny(text, <String>[
      'stress',
      'anxiety',
      'burnout',
      'burned out',
      'overwhelmed',
    ])) {
      result = _intent('stress_support', 0.86, 'mental', text);
    } else if (_hasAny(text, <String>[
      'focus',
      'attention',
      'concentration',
      'distracted',
    ])) {
      result = _intent('focus', 0.86, 'productivity', text);
    } else if (_hasAny(text, <String>[
      'procrastination',
      'procrastinate',
      'putting off',
      'avoidance',
    ])) {
      result = _intent('procrastination', 0.86, 'productivity', text);
    } else if (_hasAny(text, <String>[
      'habit',
      'routine',
      'habit building',
      'build a habit',
    ])) {
      result = _intent('habit_building', 0.84, 'productivity', text);
    } else if (_hasAny(text, <String>[
      'goal recovery',
      'off track',
      'fell behind',
      'get back on track',
    ])) {
      result = _intent('goal_recovery', 0.85, 'productivity', text);
    } else if (_hasAny(text, <String>[
      'future self',
      'future me',
      'future version',
    ])) {
      result = _intent('future_self', 0.83, 'life', text);
    } else if (_hasAny(text, <String>['purpose', 'meaning', 'my why', 'life purpose'])) {
      result = _intent('purpose', 0.83, 'life', text);
    } else if (_hasAny(text, <String>['deep work', 'time management', 'task planning', 'productivity'])) {
      result = _intent('productivity', 0.86, 'productivity', text);
    } else if (_hasAny(text, <String>['confidence', 'motivation', 'discipline'])) {
      result = _intent('mindset', 0.84, 'mental', text);
    } else if (_hasAny(text, <String>['relationship', 'career', 'learn', 'growth', 'decision'])) {
      result = _intent('life', 0.82, 'life', text);
    }

    return result;
  }

  AssistantIntent _detectConsoleIntent(String text) {
    if (_hasAny(text, <String>['timeline', 'deadline', 'overdue', 'due'])) {
      return _intent('timeline_query', 0.86, 'si_console', text);
    }
    if (_hasAny(text, <String>['goal', 'target', 'objective', 'milestone'])) {
      return _intent('goal_query', 0.85, 'si_console', text);
    }
    if (_hasAny(text, <String>['task', 'todo', 'next action', 'priority'])) {
      return _intent('task_query', 0.84, 'si_console', text);
    }
    if (_hasAny(text, <String>['memory', 'remember', 'recall', 'forget'])) {
      return _intent('memory_query', 0.8, 'si_console', text);
    }
    if (_hasAny(text, <String>['progress', 'on track', 'how am i doing'])) {
      return _intent('progress_query', 0.8, 'si_console', text);
    }
    if (_hasAny(text, <String>['analyze', 'insight', 'trend', 'metrics'])) {
      return _intent('analytics_query', 0.8, 'si_console', text);
    }
    if (_hasAny(text, <String>[
      'life summary',
      'summarize my life',
      'my life',
    ])) {
      return _intent('life_query', 0.8, 'si_console', text);
    }
    return _intent('recommendation_query', 0.68, 'si_console', text);
  }

  AssistantIntent _intent(
    String label,
    double confidence,
    String group,
    String text,
  ) {
    return AssistantIntent(
      label: label,
      confidence: confidence,
      surface: group,
      metadata: <String, dynamic>{
        'group': group,
        'sample': text.isEmpty ? null : text,
      },
    );
  }

  bool _hasAny(String text, List<String> patterns) =>
      patterns.any(text.contains);
}
