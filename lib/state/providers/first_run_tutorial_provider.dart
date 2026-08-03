import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String creatorFirstRunTutorialCompleteStorageKey =
    'creator_first_run_tutorial_complete_v1';

final Provider<FirstRunTutorialController> firstRunTutorialControllerProvider =
    Provider<FirstRunTutorialController>((ref) {
      return FirstRunTutorialController();
    });

class FirstRunTutorialState {
  const FirstRunTutorialState({
    required this.isActive,
    required this.currentStep,
    required this.completed,
    required this.dismissed,
  });

  final bool isActive;
  final int currentStep;
  final bool completed;
  final bool dismissed;

  FirstRunTutorialState copyWith({
    bool? isActive,
    int? currentStep,
    bool? completed,
    bool? dismissed,
  }) {
    return FirstRunTutorialState(
      isActive: isActive ?? this.isActive,
      currentStep: currentStep ?? this.currentStep,
      completed: completed ?? this.completed,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

class FirstRunTutorialController extends ChangeNotifier {
  FirstRunTutorialController({this.maxSteps = 3});

  final int maxSteps;

  FirstRunTutorialState _state = const FirstRunTutorialState(
    isActive: false,
    currentStep: 0,
    completed: false,
    dismissed: false,
  );

  FirstRunTutorialState get state => _state;

  // Defers notifyListeners to post-frame when called mid-animation.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Future<void> start() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool alreadyCompleted =
        prefs.getBool(creatorFirstRunTutorialCompleteStorageKey) ?? false;
    if (alreadyCompleted) {
      _state = _state.copyWith(
        isActive: false,
        completed: true,
        dismissed: true,
      );
      _notify();
      return;
    }

    if (_state.completed) {
      return;
    }

    _state = _state.copyWith(
      isActive: true,
      currentStep: 0,
      completed: false,
      dismissed: false,
    );
    _notify();
  }

  Future<void> next() async {
    if (!_state.isActive) {
      return;
    }

    final int nextStep = _state.currentStep + 1;
    if (nextStep >= maxSteps) {
      await complete();
      return;
    }

    _state = _state.copyWith(isActive: true, currentStep: nextStep);
    _notify();
  }

  Future<void> complete() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(creatorFirstRunTutorialCompleteStorageKey, true);
    _state = _state.copyWith(
      isActive: false,
      currentStep: maxSteps,
      completed: true,
    );
    _notify();
  }

  Future<void> skip() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(creatorFirstRunTutorialCompleteStorageKey, true);
    _state = _state.copyWith(isActive: false, completed: true, dismissed: true);
    _notify();
  }

  Future<void> dismiss() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(creatorFirstRunTutorialCompleteStorageKey, true);
    _state = _state.copyWith(isActive: false, dismissed: true);
    _notify();
  }
}
