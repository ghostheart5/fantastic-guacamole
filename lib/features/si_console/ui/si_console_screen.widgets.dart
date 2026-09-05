part of 'si_console_screen.dart';

class _ContextStatusBanner extends StatelessWidget {
  const _ContextStatusBanner({
    required this.availabilityLoading,
    required this.availabilityError,
    required this.available,
    required this.loading,
    required this.error,
    required this.snapshot,
    required this.onRetry,
  });

  final bool availabilityLoading;
  final Object? availabilityError;
  final bool available;
  final bool loading;
  final Object? error;
  final SIV2EvidenceSnapshot? snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final SIRoutineCopy copy = ChronoSparkLocalizations.of(context).siRoutine;
    final String message;
    final IconData icon;
    final Color accent;
    if (availabilityError != null) {
      message = copy.accessCheckFailed;
      icon = Icons.error_outline_rounded;
      accent = Colors.amberAccent;
    } else if (availabilityLoading) {
      message = copy.checkingAccess;
      icon = Icons.sync_rounded;
      accent = AppColors.neonCyan;
    } else if (!available) {
      message = copy.accessUnavailable;
      icon = Icons.lock_outline_rounded;
      accent = Colors.amberAccent;
    } else if (error != null) {
      message = PublicFailure.from(
        error!,
        fallback: copy.contextUnavailable,
      ).message;
      icon = Icons.error_outline_rounded;
      accent = Colors.amberAccent;
    } else if (loading) {
      message = copy.initializingContext;
      icon = Icons.sync_rounded;
      accent = AppColors.neonCyan;
    } else {
      final SIV2EvidenceSnapshot? evidence = snapshot;
      final int evidenceCount = evidence == null
          ? 0
          : evidence.tasks.length +
                evidence.goals.length +
                evidence.milestones.length +
                evidence.timeline.length;
      message = evidence == null
          ? copy.evidenceUnavailable
          : evidenceCount == 0
          ? copy.noEvidence(_personContextBoundary(evidence, copy))
          : copy.evidenceReady(
              tasks: evidence.tasks.length,
              goals: evidence.goals.length,
              milestones: evidence.milestones.length,
              timeline: evidence.timeline.length,
              personBoundary: _personContextBoundary(evidence, copy),
            );
      icon = Icons.verified_rounded;
      accent = Colors.greenAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.82),
        border: Border(
          bottom: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: message,
              child: ExcludeSemantics(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          if (availabilityError != null || error != null) ...<Widget>[
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: Text(copy.retryEvidence)),
          ],
        ],
      ),
    );
  }
}

String _personContextBoundary(
  SIV2EvidenceSnapshot snapshot,
  SIRoutineCopy copy,
) {
  final SIV2PersonContextEvidence? context = snapshot.personContext;
  if (context == null) {
    return copy.personContextUnavailable;
  }
  if (context.isEmpty) {
    return copy.personContextNotRelevant;
  }
  return copy.personContextEvidence(context.signals.length);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onSpeakSummary,
    required this.onSpeakAccessibility,
  });
  final VoidCallback onBack;
  final VoidCallback? onSpeakSummary;
  final VoidCallback onSpeakAccessibility;

  @override
  Widget build(BuildContext context) {
    final SIRoutineCopy copy = ChronoSparkLocalizations.of(context).siRoutine;
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                label: copy.backToNexus,
                button: true,
                onTap: onBack,
                child: IconButton(
                  tooltip: copy.backToNexus,
                  onPressed: onBack,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TemporalScreenHeader(
                  title: copy.title,
                  subtitle: largeText ? null : copy.subtitle,
                  eyebrow: largeText ? null : copy.eyebrow,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: copy.readSummary,
                  onPressed: onSpeakSummary,
                  color: AppColors.neonCyan,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: copy.accessibilityGuide,
                  onPressed: onSpeakAccessibility,
                  color: Colors.white70,
                  icon: const Icon(Icons.accessibility_new_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsoleWelcome extends StatelessWidget {
  const _ConsoleWelcome({
    required this.enabled,
    required this.snapshot,
    required this.onQuestion,
  });

  final bool enabled;
  final SIV2EvidenceSnapshot? snapshot;
  final ValueChanged<String> onQuestion;

  @override
  Widget build(BuildContext context) {
    final SIRoutineCopy copy = ChronoSparkLocalizations.of(context).siRoutine;
    final SIV2EvidenceSnapshot? evidence = snapshot;
    final int evidenceCount = evidence == null
        ? 0
        : evidence.tasks.length +
              evidence.goals.length +
              evidence.milestones.length +
              evidence.timeline.length;
    final String body = !enabled
        ? copy.unavailableSavedWork
        : evidenceCount == 0
        ? copy.welcomeNoEvidence
        : copy.welcomeReady;
    final List<String> questions = copy.welcomeExamples(
      noEvidence: evidenceCount == 0,
    );

    return Padding(
      key: const Key('si-console-welcome'),
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.askFromEvidence,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions
                .map(
                  (String question) => OutlinedButton.icon(
                    onPressed: enabled ? () => onQuestion(question) : null,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: Text(question),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _BubbleTile extends ConsumerWidget {
  const _BubbleTile({required this.msg, this.onReport});
  final _Msg msg;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final bool isSpanish = l10n.isSpanish;
    final SIRoutineCopy copy = l10n.siRoutine;
    final bool isUser = msg.isUser;
    final String? emotion = msg.emotion;
    final bool systemPanel = msg.systemPanel && !isUser;
    final Color bubbleColor = isUser
        ? AppColors.neonViolet.withValues(alpha: 0.16)
        : AppColors.bgSecondary.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _SIAvatar(emotion: msg.emotion),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  liveRegion: !isUser,
                  label: isUser ? copy.yourQuery : copy.siResponse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUser
                            ? Colors.purple.withValues(alpha: 0.25)
                            : systemPanel
                            ? Colors.white24
                            : AppColors.neonCyan.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser && emotion != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _ResponseToneTag(tone: emotion),
                          ),
                        if (!isUser &&
                            msg.processingMode != AIProcessingMode.unknown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _ProcessingModeTag(mode: msg.processingMode),
                          ),
                        if (msg.siV2 case final SIV2Response response)
                          _SIV2ResponseCard(response: response)
                        else
                          TypingText(
                            msg.text,
                            key: ValueKey<String>(
                              'si-msg-${msg.isUser}-${msg.text}',
                            ),
                            animate: false,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: isUser ? Colors.white70 : Colors.white,
                              fontFamily: null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isUser && msg.rationale != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        if (msg.rationale != null &&
                            msg.rationale!.trim().isNotEmpty)
                          copy.whyThisAppears(msg.rationale!.trim()),
                      ].join('\n'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Semantics(
                        button: true,
                        label: isSpanish
                            ? 'Leer respuesta en voz alta'
                            : 'Read response aloud',
                        child: TextButton.icon(
                          onPressed: () => unawaited(
                            ref.read(voiceServiceProvider).speak(msg.text),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 16),
                          label: Text(isSpanish ? 'ESCUCHAR' : 'SPEAK'),
                        ),
                      ),
                      if (onReport != null)
                        Semantics(
                          button: true,
                          label: isSpanish
                              ? 'Reportar respuesta'
                              : 'Report response',
                          child: TextButton.icon(
                            onPressed: onReport,
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: Text(isSpanish ? 'REPORTAR' : 'REPORT'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SIV2ResponseCard extends StatelessWidget {
  const _SIV2ResponseCard({required this.response});

  final SIV2Response response;

  @override
  Widget build(BuildContext context) {
    final SIRoutineCopy copy = ChronoSparkLocalizations.of(context).siRoutine;
    return Container(
      key: const Key('si-v2-response'),
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _section(copy.directAnswer, <String>[
            response.directAnswer,
          ], emptyLabel: copy.noneIdentified),
          _section(copy.recommendation, <String>[
            response.recommendation,
          ], emptyLabel: copy.noneIdentified),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              key: const Key('si-v2-response-advanced'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                copy.advanced,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                copy.responseAdvancedSubtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              children: <Widget>[
                _section(
                  copy.observedFacts,
                  response.observedFacts
                      .map((SIV2Statement item) => item.text)
                      .toList(),
                  emptyLabel: copy.noneIdentified,
                ),
                _section(
                  copy.userReportedContext,
                  response.userReportedEvidence
                      .map((SIV2Statement item) => item.text)
                      .toList(),
                  emptyLabel: copy.noneIdentified,
                ),
                _section(
                  copy.deterministicCalculations,
                  response.calculations
                      .map((SIV2Statement item) => item.text)
                      .toList(),
                  accentOverride: AppColors.neonViolet,
                  emptyLabel: copy.noneIdentified,
                ),
                _section(
                  copy.inferences,
                  response.inferences
                      .map((SIV2Statement item) => item.text)
                      .toList(),
                  accentOverride: AppColors.memoryAmber,
                  emptyLabel: copy.noneIdentified,
                ),
                _section(
                  copy.missingOrConflicting,
                  <String>[
                    ...response.missingInformation,
                    ...response.conflicts.map(
                      (SIV2Conflict item) =>
                          '${item.severity.name.toUpperCase()}: ${item.summary}',
                    ),
                  ],
                  accentOverride: AppColors.recallRed,
                  emptyLabel: copy.noneIdentified,
                ),
                _section(
                  copy.scenarios,
                  response.scenarios
                      .map(
                        (SIV2Scenario item) =>
                            '${item.label}: ${item.projectedEffect}',
                      )
                      .toList(),
                  accentOverride: AppColors.memoryAmber,
                  emptyLabel: copy.noneIdentified,
                ),
                _section(
                  copy.scenarioAssumptions,
                  response.scenarioAssumptions,
                  accentOverride: AppColors.memoryAmber,
                  emptyLabel: copy.noneIdentified,
                ),
                _section(copy.confidenceAnatomy, <String>[
                  copy.evidenceStrength(response.confidence.strength.name),
                  copy.confidenceCoverage(
                    covered: response.confidence.coveredSignals,
                    required: response.confidence.requiredSignals,
                  ),
                  copy.confidenceFreshness(response.confidence.freshness.name),
                  copy.confidenceConflicts(response.confidence.conflictCount),
                  copy.confidenceAssumptions(
                    response.confidence.assumptionCount,
                  ),
                ], emptyLabel: copy.noneIdentified),
                _section(
                  copy.evidenceLinks,
                  response.evidenceLinks
                      .map(
                        (SIV2EvidenceLink item) =>
                            '${item.label} — ${item.uri}',
                      )
                      .toList(),
                  bottomPadding: 0,
                  emptyLabel: copy.noneIdentified,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<String> values, {
    double bottomPadding = 14,
    Color? accentOverride,
    String emptyLabel = 'None identified.',
  }) {
    final List<String> visible = values
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    final Color accent =
        accentOverride ??
        switch (title) {
          'OBSERVED FACTS' => AppColors.neonCyan,
          'DETERMINISTIC CALCULATIONS' => AppColors.neonViolet,
          'INFERENCES' ||
          'SCENARIOS' ||
          'SCENARIO ASSUMPTIONS' => AppColors.memoryAmber,
          'MISSING OR CONFLICTING INFORMATION' => AppColors.recallRed,
          _ => AppColors.neonCyan,
        };
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (visible.isEmpty)
              Text(
                emptyLabel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              )
            else
              ...visible.map(
                (String item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    visible.length == 1 ? item : '• $item',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SIAvatar extends StatelessWidget {
  const _SIAvatar({this.emotion});
  final String? emotion;

  Color get _color {
    switch (emotion) {
      case 'engaged':
        return Colors.blueAccent;
      case 'confident':
        return Colors.cyanAccent;
      case 'driven':
        return Colors.deepOrangeAccent;
      case 'cautious':
        return Colors.amberAccent;
      case 'strained':
        return Colors.redAccent;
      default:
        return AppColors.neonCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1520),
          border: Border.all(color: _color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: _color.withValues(alpha: 0.25), blurRadius: 8),
          ],
        ),
        child: Center(
          child: Text(
            'SI',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
              color: _color,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponseToneTag extends StatelessWidget {
  const _ResponseToneTag({required this.tone});
  final String tone;

  Color get _color {
    switch (tone) {
      case 'engaged':
        return Colors.blueAccent;
      case 'confident':
        return Colors.cyanAccent;
      case 'driven':
        return Colors.deepOrangeAccent;
      case 'cautious':
        return Colors.amberAccent;
      case 'strained':
        return Colors.redAccent;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        'RESPONSE TONE: ${tone.toUpperCase()}',
        style: TextStyle(
          fontSize: 8,
          letterSpacing: 0,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProcessingModeTag extends StatelessWidget {
  const _ProcessingModeTag({required this.mode});

  final AIProcessingMode mode;

  String get _label {
    switch (mode) {
      case AIProcessingMode.external:
        return 'External AI';
      case AIProcessingMode.onDevice:
        return 'On device';
      case AIProcessingMode.onDeviceFallback:
        return 'On-device fallback';
      case AIProcessingMode.unknown:
        return 'Processing unknown';
    }
  }

  Color get _color {
    switch (mode) {
      case AIProcessingMode.external:
        return Colors.deepPurpleAccent;
      case AIProcessingMode.onDevice:
        return Colors.greenAccent;
      case AIProcessingMode.onDeviceFallback:
        return Colors.amberAccent;
      case AIProcessingMode.unknown:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Processing mode: $_label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF07111C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _color.withValues(alpha: 0.55)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'SI is analyzing the current evidence',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _SIAvatar(),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.18),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (_, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final double phase = (animation.value - i * 0.2).clamp(
                          0.0,
                          1.0,
                        );
                        final double opacity =
                            0.3 + 0.7 * math.sin(phase * math.pi);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.neonCyan,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

ButtonStyle _siSegmentedStyle(Color accent) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      return states.contains(WidgetState.selected)
          ? AppColors.background
          : Colors.white70;
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      return states.contains(WidgetState.selected)
          ? accent
          : AppColors.bgSecondary.withValues(alpha: 0.9);
    }),
    side: WidgetStatePropertyAll<BorderSide>(
      BorderSide(color: accent.withValues(alpha: 0.42)),
    ),
  );
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.entityFilterController,
    required this.scenarioAssumptionController,
    required this.onSend,
    required this.intent,
    required this.sources,
    required this.timeRange,
    required this.onIntentChanged,
    required this.onSourceChanged,
    required this.onTimeRangeChanged,
    this.compact = false,
    this.busy = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final TextEditingController entityFilterController;
  final TextEditingController scenarioAssumptionController;
  final VoidCallback onSend;
  final SIV2Intent intent;
  final Set<SIV2Source> sources;
  final SIV2TimeRange timeRange;
  final ValueChanged<SIV2Intent> onIntentChanged;
  final void Function(SIV2Source source, bool selected) onSourceChanged;
  final ValueChanged<SIV2TimeRange> onTimeRangeChanged;
  final bool compact;
  final bool busy;
  final bool enabled;

  void _insertShortcut(String shortcut) {
    controller
      ..text = '$shortcut '
      ..selection = TextSelection.collapsed(offset: shortcut.length + 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SIRoutineCopy copy = ChronoSparkLocalizations.of(context).siRoutine;
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;
    final bool interactive = enabled && !busy;

    // Recognized speech populates the query box for explicit review and
    // send - it is never auto-sent or routed as a shortcut.
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if (stoppedListening && next.recognizedText.trim().isNotEmpty) {
        controller.text = next.recognizedText.trim();
        ref.read(voiceControllerProvider.notifier).clearRecognizedText();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool forceCompact =
            constraints.hasBoundedHeight && constraints.maxHeight < 150;
        final bool effectiveCompact = compact || forceCompact;

        return Container(
          constraints: BoxConstraints(
            maxHeight: math.max(160, MediaQuery.sizeOf(context).height * 0.64),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            effectiveCompact ? 8 : 10,
            16,
            effectiveCompact ? 10 : 16,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF07111C),
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: SingleChildScrollView(
            key: const Key('si-input-scroll'),
            reverse: true,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!effectiveCompact) ...[
                  Material(
                    color: Colors.transparent,
                    child: ExpansionTile(
                      key: const Key('si-v2-advanced'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: Text(
                        copy.advanced,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        copy.advancedSubtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            copy.queryBuilder,
                            style: const TextStyle(
                              color: AppColors.neonCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<SIV2Intent>(
                            segments: SIV2Intent.values
                                .map(
                                  (SIV2Intent option) =>
                                      ButtonSegment<SIV2Intent>(
                                        value: option,
                                        label: Text(
                                          option.label,
                                          key: ValueKey<String>(
                                            'si-v2-intent-${option.name}',
                                          ),
                                        ),
                                      ),
                                )
                                .toList(growable: false),
                            selected: <SIV2Intent>{intent},
                            showSelectedIcon: false,
                            style: _siSegmentedStyle(AppColors.neonCyan),
                            onSelectionChanged: !interactive
                                ? null
                                : (Set<SIV2Intent> selection) =>
                                      onIntentChanged(selection.first),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<SIV2Source>(
                            segments: SIV2Source.values
                                .map(
                                  (SIV2Source source) =>
                                      ButtonSegment<SIV2Source>(
                                        value: source,
                                        label: Text(
                                          source.label,
                                          key: ValueKey<String>(
                                            'si-v2-source-${source.name}',
                                          ),
                                        ),
                                      ),
                                )
                                .toList(growable: false),
                            selected: sources,
                            showSelectedIcon: false,
                            multiSelectionEnabled: true,
                            emptySelectionAllowed: false,
                            style: _siSegmentedStyle(AppColors.neonViolet),
                            onSelectionChanged: !interactive
                                ? null
                                : (Set<SIV2Source> selection) {
                                    for (final SIV2Source source
                                        in SIV2Source.values) {
                                      final bool selected = selection.contains(
                                        source,
                                      );
                                      if (selected !=
                                          sources.contains(source)) {
                                        onSourceChanged(source, selected);
                                      }
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<SIV2TimeRange>(
                            segments: SIV2TimeRange.values
                                .map(
                                  (SIV2TimeRange option) =>
                                      ButtonSegment<SIV2TimeRange>(
                                        value: option,
                                        label: Text(
                                          option.label,
                                          key: ValueKey<String>(
                                            'si-v2-range-${option.name}',
                                          ),
                                        ),
                                      ),
                                )
                                .toList(growable: false),
                            selected: <SIV2TimeRange>{timeRange},
                            showSelectedIcon: false,
                            style: _siSegmentedStyle(AppColors.memoryAmber),
                            onSelectionChanged: !interactive
                                ? null
                                : (Set<SIV2TimeRange> selection) =>
                                      onTimeRangeChanged(selection.first),
                          ),
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder:
                              (BuildContext context, BoxConstraints fields) {
                                final bool stackFields =
                                    fields.maxWidth < 600 ||
                                    MediaQuery.textScalerOf(context).scale(1) >
                                        1.3;
                                final Widget entityField = TextField(
                                  key: const Key('si-v2-entity-filter'),
                                  controller: entityFilterController,
                                  enabled: interactive,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: copy.entityFilter,
                                    labelStyle: const TextStyle(
                                      color: AppColors.neonCyan,
                                    ),
                                    floatingLabelStyle: const TextStyle(
                                      color: AppColors.neonCyan,
                                    ),
                                  ),
                                );
                                final Widget assumptionField = TextField(
                                  key: const Key('si-v2-assumption'),
                                  controller: scenarioAssumptionController,
                                  enabled: interactive,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    labelText: copy.scenarioAssumption,
                                    labelStyle: const TextStyle(
                                      color: AppColors.neonCyan,
                                    ),
                                    floatingLabelStyle: const TextStyle(
                                      color: AppColors.neonCyan,
                                    ),
                                  ),
                                );
                                if (stackFields) {
                                  return Column(
                                    children: <Widget>[
                                      entityField,
                                      const SizedBox(height: 8),
                                      assumptionField,
                                    ],
                                  );
                                }
                                return Row(
                                  children: <Widget>[
                                    Expanded(child: entityField),
                                    const SizedBox(width: 8),
                                    Expanded(child: assumptionField),
                                  ],
                                );
                              },
                        ),
                        const SizedBox(height: 6),
                        PopupMenuButton<SIConsoleShortcutDefinition>(
                          key: const Key('si-v2-power-alias-menu'),
                          enabled: interactive,
                          tooltip: copy.choosePowerAlias,
                          color: const Color(0xFF0A1520),
                          onSelected:
                              (SIConsoleShortcutDefinition definition) =>
                                  _insertShortcut(definition.shortcut),
                          itemBuilder: (BuildContext context) =>
                              SIConsoleShortcutRegistry.chips
                                  .map(
                                    (
                                      SIConsoleShortcutDefinition definition,
                                    ) => PopupMenuItem<SIConsoleShortcutDefinition>(
                                      value: definition,
                                      child: Text(
                                        '${definition.shortcut} · ${copy.shortcutLabel(definition)} — ${copy.shortcutDescription(definition)}',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1520),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.neonCyan.withValues(
                                  alpha: 0.34,
                                ),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.terminal_rounded,
                                  size: 18,
                                  color: AppColors.neonCyan,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    copy.powerAliases,
                                    style: const TextStyle(
                                      color: AppColors.neonCyan,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  size: 18,
                                  color: Color(0xFFAEB9D0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            final List<SIConsoleShortcutDefinition>
                            suggestions =
                                SIConsoleShortcutRegistry.autocomplete(
                                  value.text,
                                );
                            if (suggestions.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: suggestions
                                    .map(
                                      (definition) => OutlinedButton(
                                        key: ValueKey<String>(
                                          'si-shortcut-autocomplete-${definition.id}',
                                        ),
                                        onPressed: !interactive
                                            ? null
                                            : () => _insertShortcut(
                                                definition.shortcut,
                                              ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 48),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          '${definition.shortcut} · ${copy.shortcutLabel(definition)}',
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('si-query-input'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        enabled: interactive,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        cursorColor: AppColors.neonCyan,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: copy.queryLabel,
                          labelStyle: const TextStyle(
                            color: AppColors.neonCyan,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: AppColors.neonCyan,
                          ),
                          hintText: copy.queryHint,
                          hintStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A1520),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!busy) onSend();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (ref.watch(voiceInputEnabledProvider))
                      Semantics(
                        liveRegion: listening,
                        child: SmartPressable(
                          semanticLabel: copy.voiceInputLabel(
                            listening: listening,
                          ),
                          enabled: interactive,
                          onTap: () async {
                            if (listening) {
                              await ref
                                  .read(voiceControllerProvider.notifier)
                                  .stopListening();
                              return;
                            }
                            await ref
                                .read(voiceControllerProvider.notifier)
                                .startListening();
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: listening
                                  ? AppColors.neonCyan.withValues(alpha: 0.22)
                                  : !interactive
                                  ? const Color(0xFF151B22)
                                  : const Color(0xFF102436),
                              border: Border.all(
                                color: !interactive
                                    ? Colors.white12
                                    : AppColors.neonCyan,
                              ),
                            ),
                            child: Icon(
                              listening ? Icons.mic : Icons.mic_none_rounded,
                              color: !interactive
                                  ? Colors.white38
                                  : AppColors.neonCyan,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    SmartPressable(
                      semanticLabel: copy.sendLabel(
                        enabled: enabled,
                        busy: busy,
                      ),
                      enabled: interactive,
                      onTap: onSend,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: !interactive
                              ? const Color(0xFF151B22)
                              : const Color(0xFF102436),
                          border: Border.all(
                            color: !interactive
                                ? Colors.white12
                                : AppColors.neonCyan,
                          ),
                        ),
                        child: Icon(
                          busy
                              ? Icons.hourglass_top_rounded
                              : Icons.send_rounded,
                          color: !interactive
                              ? Colors.white38
                              : AppColors.neonCyan,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
