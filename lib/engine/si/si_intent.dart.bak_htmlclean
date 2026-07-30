// lib/engine/si/si_intent.dart

class SIIntentLabels {
  static const String generalQuery = 'general_query';
  static const String startFocus = 'start_focus';
  static const String getTask = 'get_task';
  static const String reflect = 'reflect';
  static const String insightRequest = 'insight_request';
  static const String productivityOptimization = 'productivity_optimization';
  static const String decisionSupport = 'decision_support';
}

class SIIntentUtils {
  const SIIntentUtils();

  String actionFor(String intent) {
    switch (intent) {
      case SIIntentLabels.startFocus:
        return 'launch_focus_session';
      case SIIntentLabels.getTask:
        return 'present_task_recommendation';
      case SIIntentLabels.reflect:
        return 'open_reflection_flow';
      case SIIntentLabels.insightRequest:
        return 'show_insight_summary';
      default:
        return 'respond_conversationally';
    }
  }

  bool isActionIntent(String intent) =>
      intent == SIIntentLabels.startFocus || intent == SIIntentLabels.getTask;
}
