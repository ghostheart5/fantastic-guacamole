import 'package:fantastic_guacamole/engine/si/models/si_state.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';

class SignalsService {
  const SignalsService();

  SignalsBundle build(SIState state) {
    final List<Signal> signals = _generate(state);
    final double score = (state.energy * 0.6 + (1 - state.fatigue) * 0.4).clamp(
      0.0,
      1.0,
    );
    final String summary = signals.isEmpty
        ? 'No notable system patterns yet.'
        : signals.length == 1
        ? signals.first.title
        : '${signals.first.title} • ${signals.length - 1} more signals';
    return SignalsBundle(items: signals, summary: summary, healthScore: score);
  }

  List<Signal> _generate(SIState state) {
    final List<Signal> signals = <Signal>[];
    if (state.fatigue > 0.7) {
      signals.add(
        const Signal(
          title: 'Overload Detected',
          description:
              'Fatigue is high. Consider a short recovery block before the next task.',
        ),
      );
    }
    if (state.energy > 0.6) {
      signals.add(
        const Signal(
          title: 'High Energy Window',
          description:
              'Your attention is strong. Prioritise your hardest task now.',
        ),
      );
    } else if (state.energy < 0.35) {
      signals.add(
        const Signal(
          title: 'Low Energy Detected',
          description:
              'Energy reserves are low. Shift to lighter tasks or take a break.',
        ),
      );
    }
    if (state.completedToday >= 3) {
      signals.add(
        Signal(
          title: 'Strong Progress',
          description:
              'You have completed ${state.completedToday} tasks today. Momentum is building.',
        ),
      );
    } else if (state.completedToday == 0) {
      signals.add(
        const Signal(
          title: 'No Tasks Completed',
          description:
              'Start with the smallest task on your list to break inertia.',
        ),
      );
    }
    if (state.fatigue < 0.3 && state.energy > 0.7) {
      signals.add(
        const Signal(
          title: 'Peak Condition',
          description:
              'Low fatigue and high energy. Ideal conditions for deep work.',
        ),
      );
    }
    return signals;
  }
}
