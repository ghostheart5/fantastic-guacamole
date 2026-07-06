import 'package:fantastic_guacamole/tutorial/tutorial_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TutorialResetService {
  const TutorialResetService(this._ref);

  final Ref _ref;

  Future<void> resetAll() {
    return _controller.reset();
  }

  Future<void> replayOnboarding() {
    return _controller.replayOnboarding();
  }

  Future<void> showAgain(String stepId) {
    return _controller.showAgain(stepId);
  }

  Future<void> revealStep(String stepId) {
    return _controller.revealStep(stepId);
  }

  Future<void> skipStep(String stepId) {
    return _controller.skipStep(stepId);
  }

  Future<void> completeStep(String stepId) {
    return _controller.completeStep(stepId);
  }

  TutorialProgressController get _controller {
    return _ref.read(tutorialProgressProvider.notifier);
  }
}

final tutorialResetServiceProvider = Provider<TutorialResetService>((ref) {
  return TutorialResetService(ref);
});
