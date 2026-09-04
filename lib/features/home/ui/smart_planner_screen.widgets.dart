part of 'smart_planner_screen.dart';

class _Exchange {
  const _Exchange({required this.question, required this.answer});
  final String question;
  final String answer;
}

class _PlannerAvailabilityStatus extends StatelessWidget {
  const _PlannerAvailabilityStatus({
    required this.availability,
    required this.onRetry,
  });

  final AsyncValue<bool> availability;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    final String message;
    final IconData icon;
    final Color accent;
    if (availability.isLoading) {
      message = copy.checkingAccess;
      icon = Icons.sync_rounded;
      accent = AppColors.neonCyan;
    } else if (availability.hasError) {
      message = copy.accessCheckFailed;
      icon = Icons.error_outline_rounded;
      accent = AppColors.memoryAmber;
    } else if (availability.asData?.value != true) {
      message = copy.accessUnavailable;
      icon = Icons.lock_outline_rounded;
      accent = AppColors.memoryAmber;
    } else {
      message = copy.onDeviceReady;
      icon = Icons.verified_rounded;
      accent = Colors.greenAccent;
    }

    return Semantics(
      key: const Key('planner-availability-status'),
      liveRegion: true,
      label: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (availability.hasError)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(copy.retryAccessCheck),
            ),
        ],
      ),
    );
  }
}

class _PreferenceMemoryChoice {
  const _PreferenceMemoryChoice({
    required this.text,
    required this.retentionDays,
  });

  final String text;
  final int retentionDays;
}

class _PlannerV2ResponsePanel extends StatelessWidget {
  const _PlannerV2ResponsePanel({
    required this.response,
    required this.onRememberPreference,
    required this.showWhy,
    required this.showEvidence,
    required this.onUseThisPlan,
    required this.onMakeSmaller,
    required this.onDifferentApproach,
    required this.onToggleWhy,
    required this.onToggleEvidence,
    this.actionStatus,
  });

  final PlannerV2Response response;
  final String? actionStatus;
  final VoidCallback onRememberPreference;
  final bool showWhy;
  final bool showEvidence;
  final VoidCallback onUseThisPlan;
  final VoidCallback onMakeSmaller;
  final VoidCallback onDifferentApproach;
  final VoidCallback onToggleWhy;
  final VoidCallback onToggleEvidence;

  @override
  Widget build(BuildContext context) {
    return _PlannerPanel(
      label: 'PLANNER V2',
      labelFontSize: 13,
      accentColor: AppColors.memoryAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TemporalStatusRow(
            icon: Icons.verified_user_outlined,
            text: 'ON-DEVICE PLANNER V2 · DETERMINISTIC',
            color: AppColors.neonCyan,
          ),
          if (response.isClarification) ...[
            _section(
              'ONE CLARIFYING QUESTION',
              _body(response.usefulQuestion!),
            ),
          ] else ...[
            _section(
              'YOUR PLAN + TRADEOFF',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanSpectrumOptionCard(option: response.recommendedOption),
                  const SizedBox(height: 5),
                  _body('Tradeoff: ${response.recommendedOption.tradeoff}'),
                ],
              ),
            ),
            _section('ONE CONCRETE NEXT STEP', _body(response.nextStep)),
            if (showWhy)
              _section('WHY THIS', _body(response.recommendationReason)),
            if (showEvidence)
              _section(
                'EVIDENCE',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: response.verifiedEvidence
                      .map(
                        (String item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '• $item',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('planner-use-this-plan'),
                  onPressed: onUseThisPlan,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Use this plan'),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-make-smaller'),
                  onPressed: onMakeSmaller,
                  icon: const Icon(Icons.compress_rounded, size: 18),
                  label: const Text('Make smaller'),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-different-approach'),
                  onPressed: onDifferentApproach,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Different approach'),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-why-this'),
                  onPressed: onToggleWhy,
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: const Text('Why this'),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-evidence'),
                  onPressed: onToggleEvidence,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Evidence'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('planner-remember-preference'),
              onPressed: onRememberPreference,
              child: const Text('Remember a preference'),
            ),
          ],
          if (actionStatus != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              label: actionStatus ?? '',
              child: ExcludeSemantics(
                child: Text(
                  actionStatus ?? '',
                  style: const TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.memoryAmber,
              fontSize: 13,
              letterSpacing: 0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  static Widget _body(String text) => Text(
    text,
    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
  );
}

class _PlannerExternalExplanationPanel extends StatelessWidget {
  const _PlannerExternalExplanationPanel({
    required this.result,
    required this.error,
    required this.requesting,
    required this.retryingExistingRequest,
    required this.onRequest,
  });

  final PlannerExplanationResult? result;
  final String? error;
  final bool requesting;
  final bool retryingExistingRequest;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final PlannerExplanationResult? completed = result;
    final String buttonLabel = requesting
        ? 'REQUESTING...'
        : retryingExistingRequest
        ? 'Retry same request'
        : completed == null
        ? 'Explain this plan'
        : 'Request another explanation';
    return _PlannerPanel(
      label: 'EXTERNAL AI EXPLANATION · OPTIONAL · READ-ONLY',
      labelFontSize: 13,
      accentColor: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Planner V2 remains the decision authority. This separate explanation cannot change or save your plan.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
          if (completed != null) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              label: 'Optional external AI explanation ready',
              child: ExcludeSemantics(
                child: Text(
                  completed.explanation ?? '',
                  key: const Key('planner-explanation-result'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${completed.provider} · ${completed.modelLabel} · ${completed.creditsCharged} AI credits · no plan changes',
              style: const TextStyle(
                color: AppColors.neonViolet,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: error,
              child: ExcludeSemantics(
                child: Text(
                  error!,
                  key: const Key('planner-explanation-error'),
                  style: const TextStyle(
                    color: AppColors.recallRed,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('planner-explanation-request'),
            onPressed: requesting ? null : onRequest,
            icon: requesting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _PlanSpectrumOptionCard extends StatelessWidget {
  const _PlanSpectrumOptionCard({required this.option});

  final PlannerOption option;

  @override
  Widget build(BuildContext context) {
    final String label = switch (option.kind) {
      PlannerOptionKind.minimum => 'MINIMUM',
      PlannerOptionKind.bestFit => 'BEST-FIT',
      PlannerOptionKind.stretch => 'STRETCH',
    };
    final Color accent = switch (option.kind) {
      PlannerOptionKind.minimum => AppColors.neonCyan,
      PlannerOptionKind.bestFit => AppColors.neonViolet,
      PlannerOptionKind.stretch => AppColors.memoryAmber,
    };
    return Semantics(
      label: '$label plan',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: accent.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$label · ${option.estimatedMinutes} MIN',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    option.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpBar extends StatelessWidget {
  const _FollowUpBar({
    required this.controller,
    required this.onSend,
    required this.sending,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC0B111C),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorText != null)
              Semantics(
                liveRegion: true,
                label: 'Follow-up failed. $errorText',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.recallRed,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: AppColors.recallRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: sending ? null : onSend,
                        child: const Text('Retry follow-up'),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('planner-follow-up-field'),
                    controller: controller,
                    enabled: !sending,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!sending) onSend();
                    },
                    decoration: InputDecoration(
                      labelText: 'Follow-up question',
                      hintText: 'Send a follow-up question...',
                      hintStyle: const TextStyle(
                        color: Color(0xFFAEB9D0),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A2440),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: sending ? 'Sending message' : 'Send message',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  color: AppColors.neonCyan,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerPanel extends StatelessWidget {
  const _PlannerPanel({
    required this.label,
    required this.child,
    required this.accentColor,
    this.labelFontSize = 10,
  });

  final String label;
  final Widget child;
  final Color accentColor;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return TemporalGlassSurface(
      accent: accentColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    letterSpacing: 0,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EnergySlider extends StatelessWidget {
  const _EnergySlider({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final double? value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            const Text(
              'CURRENT ENERGY',
              style: TextStyle(
                color: Color(0xFFD7DFF0),
                fontSize: 11,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value == null ? 'NOT SET' : '${(value! * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Current energy',
          value: value == null
              ? 'Not set'
              : '${(value! * 100).round()} percent',
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: const Color(0xFF526079),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value ?? 0.5,
              onChanged: onChanged,
              semanticFormatterCallback: (double sliderValue) =>
                  '${(sliderValue * 100).round()} percent',
            ),
          ),
        ),
      ],
    );
  }
}

class _EmotionStateControl extends StatelessWidget {
  const _EmotionStateControl({required this.selected, required this.onSelect});

  final EmotionalState? selected;
  final ValueChanged<EmotionalState> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: selected == null
          ? 'Emotional state. Not set.'
          : 'Emotional state. ${selected!.name} selected.',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double spacing = 8;
          final double chipWidth = (constraints.maxWidth - (spacing * 2)) / 3;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: EmotionalState.values
                .map((EmotionalState state) {
                  final bool isSelected = selected == state;
                  return SizedBox(
                    width: chipWidth,
                    height: 48,
                    child: Semantics(
                      label: 'Select ${state.name} emotional state',
                      button: true,
                      selected: isSelected,
                      child: ExcludeSemantics(
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(
                              state.name.toUpperCase(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (_) => onSelect(state),
                          selectedColor: AppColors.neonViolet,
                          backgroundColor: AppColors.bgSecondary.withValues(
                            alpha: 0.88,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.background
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                          side: BorderSide(
                            color: AppColors.neonViolet.withValues(alpha: 0.42),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _VoiceButton extends ConsumerStatefulWidget {
  const _VoiceButton({required this.message});
  final String message;

  @override
  ConsumerState<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends ConsumerState<_VoiceButton> {
  bool _reading = false;

  Future<void> _readAloud() async {
    if (_reading) return;
    setState(() => _reading = true);
    final bool played = await ref
        .read(voiceServiceProvider)
        .speakChecked(widget.message);
    if (!mounted) return;
    setState(() => _reading = false);
    if (!played) {
      final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
        context,
      ).plannerRoutine;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.audioUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return SmartPressable(
      semanticLabel: copy.voiceReadLabel(reading: _reading),
      enabled: !_reading,
      onTap: () => unawaited(_readAloud()),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.memoryAmber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.memoryAmber.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.volume_up_rounded,
              color: AppColors.memoryAmber,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              copy.voiceReadButton(reading: _reading),
              style: const TextStyle(
                color: AppColors.memoryAmber,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceSummaryButton extends ConsumerWidget {
  const _VoiceSummaryButton({
    required this.headline,
    required this.energy,
    required this.emotion,
  });

  final String headline;
  final double? energy;
  final EmotionalState? emotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return SmartPressable(
      semanticLabel: copy.voiceSummaryLabel,
      onTap: () => unawaited(
        ref
            .read(voiceServiceProvider)
            .speakSummary(
              title: copy.voiceSummaryTitle,
              points: <String>[
                copy.energySummary(energy),
                copy.emotionSummary(emotion?.name),
                headline,
              ],
            ),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.summarize_rounded,
              color: AppColors.neonCyan,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              copy.summaryButton,
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceAccessibilityButton extends ConsumerWidget {
  const _VoiceAccessibilityButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return SmartPressable(
      semanticLabel: copy.accessibilityLabel,
      onTap: () {
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: const Color(0xFF0D1420),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            builder: (BuildContext context) {
              return SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          copy.accessibilityTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          copy.accessibilityBody,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
        unawaited(
          ref
              .read(voiceServiceProvider)
              .speakAccessibilityHint(
                surface: copy.accessibilitySurface,
                controls: copy.accessibilityControls,
              ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.accessibility_new_rounded,
              color: Colors.white70,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              copy.accessibilityButton,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicButton extends ConsumerWidget {
  const _MicButton({required this.onRecognized});

  final ValueChanged<String> onRecognized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;

    // Recognized speech populates the follow-up box for explicit review and
    // send - it is never auto-sent or routed as an action.
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if (stoppedListening && next.recognizedText.trim().isNotEmpty) {
        onRecognized(next.recognizedText.trim());
        ref.read(voiceControllerProvider.notifier).clearRecognizedText();
      }
    });

    return Semantics(
      liveRegion: listening,
      child: SmartPressable(
        semanticLabel: copy.voiceInputLabel(listening: listening),
        onTap: () async {
          if (listening) {
            await ref.read(voiceControllerProvider.notifier).stopListening();
            return;
          }
          await ref.read(voiceControllerProvider.notifier).startListening();
          if (!context.mounted) {
            return;
          }
          final String? error = ref.read(voiceControllerProvider).error;
          if (error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(copy.voiceInputUnavailable)));
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: listening
                ? AppColors.neonCyan.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: listening
                  ? AppColors.neonCyan.withValues(alpha: 0.6)
                  : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                listening ? Icons.mic : Icons.mic_none_rounded,
                color: listening ? AppColors.neonCyan : Colors.white54,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                copy.voiceInputButton(listening: listening),
                style: TextStyle(
                  color: listening ? AppColors.neonCyan : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclaimerText extends StatelessWidget {
  const _DisclaimerText();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Planning guidance safety information',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xF207111F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.28)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.neonCyan,
                size: 18,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This supports planning, not medical, nutrition, exercise, or mental-health care. For urgent or worsening symptoms, contact a qualified professional or local emergency service.',
                style: TextStyle(
                  color: Color(0xFFD7DFF0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
