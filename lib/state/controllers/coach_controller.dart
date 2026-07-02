import 'package:fantastic_guacamole/state/controllers/ai_controller.dart';
import 'package:fantastic_guacamole/state/controllers/coach_state.dart';
import 'package:fantastic_guacamole/state/controllers/insight_controller.dart';
import 'package:fantastic_guacamole/state/controllers/prediction_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);

class CoachController extends Notifier<CoachState> {
  @override
  CoachState build() {
    _generate();
    return const CoachState();
  }

  Future<void> _generate() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final pattern = await ref.read(patternInsightProvider.future);
      final response = await ref.read(aiResponseProvider.notifier).execute();
      String? evolvedResponse;
      if (response != null) {
        final String taskTitle = response.task?.title ?? '';
        if (taskTitle.isNotEmpty) {
          final prediction = await ref.read(predictionProvider(taskTitle).future);
          evolvedResponse =
              '${response.message}\n\nInsight: $pattern\n\nPrediction:\n${prediction.outcome} '
              '(${(prediction.probability * 100).toInt()}%)\n\n${prediction.explanation}';
        } else {
          evolvedResponse = '${response.message}\n\nInsight: $pattern';
        }
      }
      state = state.copyWith(loading: false, response: evolvedResponse, task: response?.task);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _generate();
  }
}
