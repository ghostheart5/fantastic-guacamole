import '../../../core/si/si_commands.dart';
import '../../../core/si/si_emotion.dart';
import '../../../core/si/si_insights.dart';
import '../../../core/si/si_kernel.dart';
import '../../../core/system/audio_service.dart';
import '../../../domain/entities/si_insight.dart';
import '../../../domain/usecases/si_console/evaluate_si_diagnostics_usecase.dart';
import '../../../domain/usecases/si_console/generate_si_insights_usecase.dart';
import '../../../domain/usecases/si_console/run_si_command_usecase.dart';

class SIConsoleState {
  final List<String> thoughts;
  final List<String> reflections;
  final double emotionLevel;
  final String emotionLabel;
  final String mood;
  final double cognitiveLoad;
  final List<double> emotionTrend;
  final List<String> emotionalPatterns;
  final List<String> insights;
  final String insightSummary;
  final String diagnostics;
  final List<String> diagnosticSignals;
  final String lastCommand;
  final List<String> navigation;

  const SIConsoleState({
    required this.thoughts,
    required this.reflections,
    required this.emotionLevel,
    required this.emotionLabel,
    required this.mood,
    required this.cognitiveLoad,
    required this.emotionTrend,
    required this.emotionalPatterns,
    required this.insights,
    required this.insightSummary,
    required this.diagnostics,
    required this.diagnosticSignals,
    required this.lastCommand,
    required this.navigation,
  });
}

class SIConsoleController {
  SIConsoleController({AudioService? audioService})
    : _kernel = SIKernel(),
      _emotion = SIEmotion(),
      _insights = SIInsights(),
      _commands = SICommands(),
      _runSICommandUseCase = RunSICommandUseCase(),
      _generateSIInsightsUseCase = GenerateSIInsightsUseCase(),
      _evaluateSIDiagnosticsUseCase = EvaluateSIDiagnosticsUseCase(),
      _audio = audioService ?? AudioService();

  final SIKernel _kernel;
  final SIEmotion _emotion;
  final SIInsights _insights;
  final SICommands _commands;
  final RunSICommandUseCase _runSICommandUseCase;
  final GenerateSIInsightsUseCase _generateSIInsightsUseCase;
  final EvaluateSIDiagnosticsUseCase _evaluateSIDiagnosticsUseCase;
  final AudioService _audio;

  final List<String> _thoughts = <String>[];
  final List<String> _reflections = <String>[];
  final List<double> _emotionTrend = <double>[];
  String _lastCommand = 'scan';

  SIConsoleState boot() {
    _thoughts
      ..clear()
      ..add(_kernel.process('System Ready'))
      ..add(_kernel.process(_commands.execute(_lastCommand)));
    _emotion.update(0.08);
    _trackEmotion();
    return _snapshot();
  }

  SIConsoleState runCommand(String rawCommand) {
    final String command = rawCommand.trim().toLowerCase();
    if (command.isNotEmpty) {
      _lastCommand = command;
    }
    _audio.playInputSend();

    final String result = _runSICommandUseCase(
      command: _lastCommand,
      runner: _commands.execute,
    );
    final String thought = _kernel.process('cmd:$_lastCommand => $result');
    _thoughts.insert(0, thought);

    if (_lastCommand == 'optimize') {
      _emotion.update(0.05);
    } else if (_lastCommand == 'stabilize') {
      _emotion.update(-0.04);
    } else if (_lastCommand == 'scan') {
      _emotion.update(0.02);
    } else {
      _emotion.update(-0.03);
    }
    _trackEmotion();

    return _snapshot();
  }

  SIConsoleState reflect(String note) {
    final String text = note.trim();
    if (text.isEmpty) {
      return _snapshot();
    }

    _thoughts.insert(0, _kernel.process('reflect:$text'));
    _reflections.insert(0, text);
    if (_reflections.length > 10) {
      _reflections.removeLast();
    }
    _emotion.update(0.01);
    _trackEmotion();
    return _snapshot();
  }

  void _trackEmotion() {
    _emotionTrend.insert(0, _emotion.level);
    if (_emotionTrend.length > 12) {
      _emotionTrend.removeLast();
    }
  }

  SIConsoleState _snapshot() {
    final List<String> insights = _buildInsights();
    final List<String> diagnosticSignals = _buildDiagnosticSignals();
    final double cognitiveLoad = _cognitiveLoad();

    return SIConsoleState(
      thoughts: List<String>.unmodifiable(
        _thoughts.isEmpty
            ? _kernel.memory.reversed.take(6).toList()
            : _thoughts.take(8).toList(),
      ),
      reflections: List<String>.unmodifiable(_reflections),
      emotionLevel: _emotion.level,
      emotionLabel: _emotionLabel(_emotion.level),
      mood: _mood(_emotion.level),
      cognitiveLoad: cognitiveLoad,
      emotionTrend: List<double>.unmodifiable(_emotionTrend),
      emotionalPatterns: _buildEmotionalPatterns(),
      insights: insights,
      insightSummary: _insights.analyze(_kernel.memory),
      diagnostics:
          'Kernel memory: ${_kernel.memory.length} | Trend samples: ${_emotionTrend.length} | Cognitive load: ${(cognitiveLoad * 100).toStringAsFixed(0)}%',
      diagnosticSignals: diagnosticSignals,
      lastCommand: _lastCommand,
      navigation: const <String>[
        'goto creator',
        'goto logs',
        'goto temporal',
        'goto settings',
      ],
    );
  }

  double _cognitiveLoad() {
    final int commandCount = _kernel.memory
        .where((String m) => m.contains('cmd:'))
        .length;
    final double pressure = (_kernel.memory.length / 24) + (commandCount / 14);
    return pressure.clamp(0, 1).toDouble();
  }

  List<String> _buildEmotionalPatterns() {
    if (_emotionTrend.length < 3) {
      return const <String>['Pattern pending: gather more emotion samples.'];
    }

    final double latest = _emotionTrend.first;
    final double oldest = _emotionTrend.last;
    final String trend = latest > oldest
        ? 'Pattern: Emotional lift is trending upward.'
        : latest < oldest
        ? 'Pattern: Emotional charge is trending downward.'
        : 'Pattern: Emotional line is flat and stable.';

    final double mean =
        _emotionTrend.reduce((double a, double b) => a + b) /
        _emotionTrend.length;
    final String volatility = mean > 0.65
        ? 'Pattern: High arousal window detected.'
        : 'Pattern: Moderate arousal window detected.';

    return <String>[trend, volatility];
  }

  String _mood(double level) {
    if (level >= 0.8) {
      return 'Aggressive Focus';
    }
    if (level >= 0.6) {
      return 'Combat Ready';
    }
    if (level >= 0.35) {
      return 'Calibrated';
    }
    return 'Recovery Mode';
  }

  List<String> _buildInsights() {
    final int thoughtCount = _kernel.memory.length;
    final int commandLike = _kernel.memory
        .where((String m) => m.contains('cmd:'))
        .length;
    final List<SIInsight> domainInsights = _generateSIInsightsUseCase(
      memoryCount: thoughtCount,
      commandCount: commandLike,
      emotionLevel: _emotion.level,
    );

    String prefix(InsightSeverity severity) {
      switch (severity) {
        case InsightSeverity.critical:
          return 'Critical';
        case InsightSeverity.warning:
          return 'Warning';
        case InsightSeverity.info:
          return 'Info';
      }
    }

    return domainInsights
        .map(
          (SIInsight insight) =>
              '${prefix(insight.severity)}: ${insight.message}',
        )
        .toList();
  }

  List<String> _buildDiagnosticSignals() {
    final int memoryCount = _kernel.memory.length;
    final int trendCount = _emotionTrend.length;
    final int commandCount = _kernel.memory
        .where((String m) => m.contains('cmd:'))
        .length;

    final diagnostics = _evaluateSIDiagnosticsUseCase(
      memoryCount: memoryCount,
      commandCount: commandCount,
      trendSamples: trendCount,
    );

    final String memorySignal = diagnostics.memoryCount > 20
        ? 'Critical: Memory pressure high at ${diagnostics.memoryCount} records.'
        : diagnostics.memoryCount > 12
        ? 'Warning: Memory pressure rising at ${diagnostics.memoryCount} records.'
        : 'Info: Memory pressure nominal at ${diagnostics.memoryCount} records.';

    final String commandSignal = diagnostics.commandCount > 8
        ? 'Warning: Command saturation detected (${diagnostics.commandCount} command events).'
        : 'Info: Command saturation nominal (${diagnostics.commandCount} command events).';

    final String trendSignal = diagnostics.trendSamples < 4
        ? 'Warning: Limited trend fidelity (${diagnostics.trendSamples} samples).'
        : 'Info: Trend fidelity stable (${diagnostics.trendSamples} samples).';

    return <String>[memorySignal, commandSignal, trendSignal];
  }

  String _emotionLabel(double level) {
    if (level >= 0.8) {
      return 'Overclocked';
    }
    if (level >= 0.6) {
      return 'Engaged';
    }
    if (level >= 0.35) {
      return 'Stable';
    }
    return 'Depleted';
  }
}
