import 'package:fantastic_guacamole/state/providers/intelligence_fusion_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CognitiveTwinMode { recovering, stabilizing, executing, accelerating }

class CognitiveTwinState {
  const CognitiveTwinState({
    required this.mode,
    required this.identityStatement,
    required this.bestAction,
    required this.warning,
    required this.plannerMessage,
  });

  final CognitiveTwinMode mode;
  final String identityStatement;
  final String bestAction;
  final String warning;
  final String plannerMessage;
}

final cognitiveTwinProvider = Provider<CognitiveTwinState>((ref) {
  final fusion = ref.watch(intelligenceFusionProvider);

  CognitiveTwinMode mode = CognitiveTwinMode.executing;

  if (fusion.operatingMode.contains('Recovery')) {
    mode = CognitiveTwinMode.recovering;
  } else if (fusion.operatingMode.contains('Stabilization')) {
    mode = CognitiveTwinMode.stabilizing;
  } else if (fusion.operatingMode.contains('Acceleration')) {
    mode = CognitiveTwinMode.accelerating;
  }

  return CognitiveTwinState(
    mode: mode,
    identityStatement:
        'The future version of you succeeds by executing the next clear action.',
    bestAction: fusion.nextAction,
    warning: fusion.primaryThreat,
    plannerMessage:
        'Stay aligned with the future state you are actively building.',
  );
});
