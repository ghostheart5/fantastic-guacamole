// lib/engine/si/si_intent.dart

class SIIntentLabels {
  static const String generalQuery = 'general_query';
  static const String startExecution = 'start_execution';
  static const String getTask = 'get_task';
  static const String reflect = 'reflect';
  static const String signalRequest = 'signal_request';
  static const String productivityOptimization = 'productivity_optimization';
  static const String decisionSupport = 'decision_support';
}

class SIIntentUtils {
  const SIIntentUtils();

  String actionFor(String intent) {
    switch (intent) {
      case SIIntentLabels.startExecution:
        return 'launch_execution_block';
      case SIIntentLabels.getTask:
        return 'present_task_recommendation';
      case SIIntentLabels.reflect:
        return 'open_reflection_flow';
      case SIIntentLabels.signalRequest:
        return 'show_signal_summary';
      default:
        return 'respond_conversationally';
    }
  }

  bool isActionIntent(String intent) =>
      intent == SIIntentLabels.startExecution ||
      intent == SIIntentLabels.getTask;
}
