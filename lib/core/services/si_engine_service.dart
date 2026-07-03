import 'package:fantastic_guacamole/domain/entities/si_decision_entity.dart';
import 'package:fantastic_guacamole/domain/usecases/generate_si_decision.dart';
import 'package:flutter/foundation.dart';

class SIEngineService {
  SIEngineService(this._generateDecision);

  final GenerateSiDecision _generateDecision;

  Future<SiDecisionEntity> think(String input) async {
    final SiDecisionEntity result = await _generateDecision(input);
    SIConsole._log(input: input, result: result);
    return result;
  }

  Future<SiDecisionEntity> getNextAction() =>
      think('what should the user do next?');
}

// ─── Console ─────────────────────────────────────────────────────────────────
// Logs every SI decision: input → intent proxy, instinct proxy, decision, output.

class SIConsole {
  SIConsole._();

  static void _log({required String input, required SiDecisionEntity result}) {
    if (!kDebugMode) return;
    debugPrint(
      '[SI] input="${_trim(input)}" '
      'intent="${_trim(result.reasoningTrace)}" '
      'instinct="${result.shouldSimplify ? "safety_first" : "progress_first"}" '
      'decision="${_trim(result.rationale)}" '
      'output="${_trim(result.action)}" '
      'tone=${result.tone} '
      'break=${result.shouldTakeBreak} '
      'focus=${result.recommendedFocusMinutes}min',
    );
  }

  static String _trim(String s, {int max = 80}) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}
