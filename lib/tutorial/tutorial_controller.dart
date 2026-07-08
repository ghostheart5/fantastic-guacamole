// lib/tutorial/tutorial_controller.dart

import 'dart:async';

import 'package:fantastic_guacamole/tutorial/tutorial_asset_loader.dart';
import 'package:fantastic_guacamole/tutorial/tutorial_models.dart';
import 'package:flutter/foundation.dart';

class TutorialController extends ChangeNotifier {
  TutorialController({this.loader = const TutorialAssetLoader()});

  final TutorialAssetLoader loader;

  final Map<String, TutorialDefinition> _tutorials =
      <String, TutorialDefinition>{};
  final Set<String> _completedTutorialIds = <String>{};
  final Map<String, Object?> _state = <String, Object?>{};
  final Map<String, String> _inputs = <String, String>{};

  TutorialDefinition? _activeTutorial;
  TutorialStep? _activeStep;
  bool _running = false;
  bool _paused = false;
  String _route = '/';
  Timer? _delayTimer;

  bool get running => _running;
  bool get paused => _paused;
  String get currentRoute => _route;
  TutorialStep? get activeStep => _activeStep;
  TutorialDefinition? get activeTutorial => _activeTutorial;

  Future<void> loadAssets(List<String> paths, {bool reload = false}) async {
    if (reload) _tutorials.clear();
    final defs = await loader.loadAll(paths);
    for (final def in defs) {
      _tutorials[def.id] = def;
    }
    notifyListeners();
  }

  Future<void> start(String tutorialId, {bool restart = false}) async {
    final TutorialDefinition? tutorial = _tutorials[tutorialId];
    if (tutorial == null || tutorial.steps.isEmpty) return;

    if (restart) {
      _completedTutorialIds.remove(tutorialId);
    }

    if (_completedTutorialIds.contains(tutorialId) && !restart) {
      return;
    }

    _activeTutorial = tutorial;
    _activeStep = tutorial.steps.first;

    _running = true;
    _paused = false;

    _scheduleIfNeeded();
    notifyListeners();
  }

  Future<void> pause() async {
    if (_activeStep == null) return;
    _paused = true;
    _delayTimer?.cancel();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_activeStep == null) return;
    _paused = false;
    _scheduleIfNeeded();
    notifyListeners();
  }

  Future<void> restart() async {
    final String? id = _activeTutorial?.id;
    if (id == null) return;
    await start(id, restart: true);
  }

  Future<void> skip() async {
    final String? tutorialId = _activeTutorial?.id;
    if (tutorialId != null) {
      _completedTutorialIds.add(tutorialId);
    }
    _finish();
  }

  void updateRoute(String route) {
    _route = route;
    _validate();
  }

  void reportEvent(String event) {
    _state['event'] = event;
    _validate();
  }

  void updateState(String key, Object? value) {
    _state[key] = value;
    _validate();
  }

  void updateInput(String key, String value) {
    _inputs[key] = value;
    _validate();
  }

  Future<void> next() async {
    if (_activeTutorial == null || _activeStep == null) return;

    final TutorialStep current = _activeStep!;
    final String? branch = _branchFor(current);
    final String? nextId = branch ?? current.nextStepId;

    TutorialStep? nextStep;
    if (nextId != null && nextId.isNotEmpty) {
      nextStep = _stepById(nextId);
    } else {
      final int index = _activeTutorial!.steps.indexWhere(
        (s) => s.id == current.id,
      );
      if (index >= 0 && index + 1 < _activeTutorial!.steps.length) {
        nextStep = _activeTutorial!.steps[index + 1];
      }
    }

    if (nextStep == null) {
      _completedTutorialIds.add(_activeTutorial!.id);
      _finish();
      return;
    }

    _activeStep = nextStep;
    _scheduleIfNeeded();
    notifyListeners();
  }

  void _validate() {
    if (!_running || _paused || _activeStep == null) return;
    final TutorialStep step = _activeStep!;

    final bool complete = switch (step.trigger) {
      TutorialTriggerType.tap => _state['event'] == 'tap:${step.targetId}',
      TutorialTriggerType.longPress =>
        _state['event'] == 'longPress:${step.targetId}',
      TutorialTriggerType.route => step.route == _route,
      TutorialTriggerType.state => _state[step.stateKey] == step.stateValue,
      TutorialTriggerType.input => _inputs[step.inputKey] == step.expectedValue,
      TutorialTriggerType.delay => false,
      TutorialTriggerType.manual => false,
    };

    if (complete) {
      unawaited(next());
    }
  }

  String? _branchFor(TutorialStep step) {
    for (final TutorialBranch branch in step.branches) {
      if (_state[branch.whenKey] == branch.equalsValue) {
        return branch.gotoStepId;
      }
    }
    return null;
  }

  void _scheduleIfNeeded() {
    _delayTimer?.cancel();
    final TutorialStep? step = _activeStep;
    if (step == null) return;

    if (step.delayMs > 0 || step.trigger == TutorialTriggerType.delay) {
      _delayTimer = Timer(Duration(milliseconds: step.delayMs), () {
        if (!_paused && _running) unawaited(next());
      });
    } else if (step.autoAdvance) {
      _delayTimer = Timer(const Duration(milliseconds: 350), () {
        if (!_paused && _running) unawaited(next());
      });
    }
  }

  TutorialStep? _stepById(String id) {
    return _activeTutorial?.steps.cast<TutorialStep?>().firstWhere(
      (step) => step?.id == id,
      orElse: () => null,
    );
  }

  void _finish() {
    _running = false;
    _paused = false;
    _activeTutorial = null;
    _activeStep = null;
    _delayTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }
}
