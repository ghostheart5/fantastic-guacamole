import '../../entities/si_diagnostics.dart';

class EvaluateSIDiagnosticsUseCase {
  SIDiagnostics call({
    required int memoryCount,
    required int commandCount,
    required int trendSamples,
  }) {
    return SIDiagnostics(
      memoryCount: memoryCount,
      commandCount: commandCount,
      trendSamples: trendSamples,
    );
  }
}
