import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppView {
  coach,
  smartCoach,
  focus,
  insight,
  reflect,
  console,
  settings,
  progression,
  plan,
  creator,
  flowmap,
}

final appFlowProvider = NotifierProvider<AppFlowController, AppView>(
  AppFlowController.new,
);

class AppFlowController extends Notifier<AppView> {
  @override
  AppView build() => AppView.coach;

  void toCoach() => state = AppView.coach;
  void toSmartCoach() => state = AppView.smartCoach;
  void toFocus() => state = AppView.focus;
  void toInsight() => state = AppView.insight;
  void toReflect() => state = AppView.reflect;
  void toConsole() => state = AppView.console;
  void toSettings() => state = AppView.settings;
  void toProgression() => state = AppView.progression;
  void toPlan() => state = AppView.plan;
  void toCreator() => state = AppView.creator;
  void toFlowmap() => state = AppView.flowmap;
}
