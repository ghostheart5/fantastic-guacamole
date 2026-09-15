part of 'smart_planner_screen.dart';

extension on _SmartPlannerScreenState {
  Widget _buildHeader() {
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    final PlannerRoutineCopy routine = l10n.plannerRoutine;
    return TemporalScreenHeader(
      title: l10n.text(ChronoSparkString.smartPlanner),
      subtitle: routine.subtitle,
      eyebrow: routine.eyebrow,
      backTooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onBack: () => goToAppView(context, ref, AppView.nexus),
    );
  }
}

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
    this.controlsEnabled = true,
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
  final bool controlsEnabled;

  @override
  Widget build(BuildContext context) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return _PlannerPanel(
      label: copy.plannerPanelTitle,
      labelFontSize: 13,
      accentColor: AppColors.memoryAmber,
      child: Column(
        key: const Key('planner-response-panel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TemporalStatusRow(
            icon: Icons.verified_user_outlined,
            text: response.origin == PlannerResponseOrigin.deterministic
                ? copy.plannerLocalSource
                : copy.plannerExternalSource,
            color: AppColors.neonCyan,
          ),
          const SizedBox(height: 14),
          _body(response.whatIHeard),
          const SizedBox(height: 14),
          if (response.isClarification) ...[
            _section(copy.oneQuestion, _body(response.usefulQuestion!)),
          ] else ...[
            _section(
              copy.yourNextStep,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlanSpectrumOptionCard(option: response.recommendedOption),
                  const SizedBox(height: 5),
                  Text(
                    response.nextStep,
                    key: const Key('planner-next-step'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _body(response.recommendationReason),
                ],
              ),
            ),
            if (response.usefulQuestion?.trim().isNotEmpty == true)
              _section(
                copy.oneQuestion,
                _body(response.usefulQuestion!.trim()),
              ),
            if (showWhy)
              _section(
                copy.mattersMost,
                _body(
                  '${response.mattersMost}\n${copy.tradeoff(response.recommendedOption.tradeoff)}',
                ),
              ),
            if (showEvidence)
              _section(
                copy.evidence,
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
                  onPressed: controlsEnabled ? onUseThisPlan : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(copy.useThisPlan),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-make-smaller'),
                  onPressed: controlsEnabled ? onMakeSmaller : null,
                  icon: const Icon(Icons.compress_rounded, size: 18),
                  label: Text(copy.makeSmaller),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-different-approach'),
                  onPressed: controlsEnabled ? onDifferentApproach : null,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(copy.differentApproach),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-why-this'),
                  onPressed: onToggleWhy,
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: Text(copy.whyThis),
                ),
                OutlinedButton.icon(
                  key: const Key('planner-evidence'),
                  onPressed: onToggleEvidence,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(copy.evidence),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('planner-remember-preference'),
              onPressed: onRememberPreference,
              child: Text(copy.rememberPreference),
            ),
            ExpansionTile(
              key: const Key('planner-alternative-options'),
              tilePadding: EdgeInsets.zero,
              title: Text(copy.alternativeOptions),
              children: <Widget>[
                for (final PlannerOption option in response.options)
                  if (option.kind != response.recommendedKind)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _PlanSpectrumOptionCard(option: option),
                          _body(option.description),
                          _body(copy.tradeoff(option.tradeoff)),
                        ],
                      ),
                    ),
              ],
            ),
          ],
          ExpansionTile(
            key: const Key('planner-full-response'),
            tilePadding: EdgeInsets.zero,
            title: Text(copy.fullResponse),
            children: <Widget>[
              SelectableText(
                response.toAccessibleText(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
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
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    final String buttonLabel = requesting
        ? copy.explanationRequesting
        : retryingExistingRequest
        ? copy.explanationRetry
        : completed == null
        ? copy.explainPlan
        : copy.anotherExplanation;
    return _PlannerPanel(
      label: copy.externalExplanationTitle,
      labelFontSize: 13,
      accentColor: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.externalExplanationBody,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (completed != null) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              label: copy.explanationReady,
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
              '${completed.provider} · ${completed.modelLabel} · ${copy.explanationReceipt(completed.creditsCharged)}',
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
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    final String label = copy.optionKind(option.kind.name);
    final Color accent = switch (option.kind) {
      PlannerOptionKind.minimum => AppColors.neonCyan,
      PlannerOptionKind.bestFit => AppColors.neonViolet,
      PlannerOptionKind.stretch => AppColors.memoryAmber,
    };
    return Semantics(
      label: copy.optionSemantic(label),
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
    required this.listening,
    this.errorText,
    this.onRetry,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final bool listening;
  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
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
                label: copy.followUpFailed(errorText!),
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
                        onPressed: sending || listening
                            ? null
                            : onRetry ?? onSend,
                        child: Text(copy.retryFollowUp),
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
                    readOnly: listening,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!sending && !listening) onSend();
                    },
                    decoration: InputDecoration(
                      labelText: copy.followUpQuestion,
                      hintText: copy.followUpHint,
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
                  tooltip: copy.sendMessage(sending: sending),
                  onPressed: sending || listening ? null : onSend,
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
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              copy.currentEnergy.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFD7DFF0),
                fontSize: 11,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value == null
                  ? copy.notSet.toUpperCase()
                  : '${(value! * 100).round()}%',
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
          label: copy.currentEnergy,
          value: value == null
              ? copy.notSet
              : copy.energyPercent((value! * 100).round()),
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
                  copy.energyPercent((sliderValue * 100).round()),
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
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return Semantics(
      container: true,
      label: copy.emotionalSelection(selected?.name),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double spacing = 8;
          final double scaledLabelSize = MediaQuery.textScalerOf(
            context,
          ).scale(11);
          final bool singleColumn =
              scaledLabelSize >= 18 || constraints.maxWidth < 260;
          final int columns = singleColumn
              ? 1
              : copy.isSpanish || constraints.maxWidth < 330
              ? 2
              : 3;
          final double chipWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: EmotionalState.values
                .map((EmotionalState state) {
                  final bool isSelected = selected == state;
                  return SizedBox(
                    width: chipWidth,
                    height: scaledLabelSize >= 18 ? 72 : 48,
                    child: Semantics(
                      label: copy.selectEmotion(state.name),
                      button: true,
                      selected: isSelected,
                      child: ExcludeSemantics(
                        child: ChoiceChip(
                          label: Text(
                            copy.emotionName(state.name).toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          padding: EdgeInsets.zero,
                          labelPadding: EdgeInsets.zero,
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
  const _VoiceButton({required this.message, required this.languageCode});
  final String message;
  final String languageCode;

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
        .speakCheckedLocalized(
          widget.message,
          languageCode: widget.languageCode,
        );
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
    required this.summary,
    required this.languageCode,
  });

  final String summary;
  final String languageCode;

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
            .speakLocalized(summary, languageCode: languageCode),
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
  const _MicButton({required this.onRecognized, required this.onStart});

  final ValueChanged<String> onRecognized;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(voiceInputEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;

    // Recognized speech populates the follow-up box for explicit review and
    // send - it is never auto-sent or routed as an action.
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      if (next.error != null &&
          next.error != previous?.error &&
          context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(copy.voiceInputUnavailable)));
      }
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if ((next.isListening || stoppedListening) &&
          next.recognizedText.trim().isNotEmpty) {
        onRecognized(next.recognizedText.trim());
      }
      if (stoppedListening) {
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
          final VoiceController controller = ref.read(
            voiceControllerProvider.notifier,
          );
          onStart();
          final int lifecycleRevision = controller.lifecycleRevision;
          await startVoiceInputWithConsent(
            context: context,
            onStart: controller.startListening,
            consentStore: ref.read(voiceInputConsentStoreProvider),
            isCurrentRequest: () =>
                controller.lifecycleRevision == lifecycleRevision,
          );
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
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    return Semantics(
      container: true,
      label: copy.planningSafetyLabel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xF207111F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.neonCyan,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                copy.planningSafetyBody,
                style: const TextStyle(
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

class _PlannerEmotionCheckIn extends ConsumerWidget {
  const _PlannerEmotionCheckIn();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = ChronoSparkLocalizations.of(context).plannerRoutine;
    final humanContext = ref.watch(consentedHumanContextProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          routine.emotionalStateSection,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.neonViolet,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        _EmotionStateControl(
          selected: ref.watch(currentPlannerEmotionProvider),
          onSelect: (e) => ref.read(emotionCheckInProvider.notifier).set(e),
        ),
        const SizedBox(height: 8),
        Text(
          routine.emotionalStateNotice(enabled: humanContext.emotionAllowed),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        if (ref.watch(currentPlannerEmotionProvider) != null) ...[
          SwitchListTile(
            key: const Key('share-emotion-with-planning'),
            value: ref.watch(emotionCheckInProvider).shareWithPlanning,
            title: Text(
              ChronoSparkLocalizations.of(context).isSpanish
                  ? 'Usar también en SI y Nexus durante este registro'
                  : 'Also use in SI and Nexus for this check-in',
            ),
            subtitle: Text(
              ChronoSparkLocalizations.of(context).isSpanish
                  ? 'Temporal. Caduca dos horas después de seleccionarlo. No se guarda en el historial.'
                  : 'Temporary. Expires two hours after selection. Not saved to history.',
            ),
            onChanged: humanContext.emotionAllowed
                ? (value) =>
                      ref.read(emotionCheckInProvider.notifier).share(value)
                : null,
          ),
          TextButton(
            key: const Key('clear-emotion-check-in'),
            onPressed: () => ref.read(emotionCheckInProvider.notifier).clear(),
            child: Text(
              ChronoSparkLocalizations.of(context).isSpanish
                  ? 'Borrar registro emocional'
                  : 'Clear emotional check-in',
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectedPlanningNoteCard extends ConsumerWidget {
  const _SelectedPlanningNoteCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      if (ref.watch(planningNoteSelectionProvider) != null)
        ref
            .watch(selectedPlanningNoteProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(
                ChronoSparkLocalizations.of(context).isSpanish
                    ? 'La nota seleccionada no está disponible.'
                    : 'The selected note is unavailable.',
              ),
              data: (note) => ListTile(
                title: Text(
                  note == null
                      ? (ChronoSparkLocalizations.of(context).isSpanish
                            ? 'La nota ya no está disponible'
                            : 'Note is no longer available')
                      : '${ChronoSparkLocalizations.of(context).isSpanish ? 'Nota seleccionada' : 'Selected note'}: ${note.title}',
                ),
                subtitle: Text(
                  ChronoSparkLocalizations.of(context).isSpanish
                      ? 'Solo esta sesión de planificación; caduca en dos horas.'
                      : 'Temporary planning context; expires two hours after selection.',
                ),
                trailing: IconButton(
                  tooltip: ChronoSparkLocalizations.of(context).isSpanish
                      ? 'Quitar nota del contexto'
                      : 'Remove note from context',
                  onPressed: () =>
                      ref.read(planningNoteSelectionProvider.notifier).clear(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
    ],
  );
}

Widget _bubble(String text, {required bool isUser}) {
  return Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.neonViolet.withValues(alpha: 0.18)
            : AppColors.neonCyan.withValues(alpha: 0.10),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(isUser ? 8 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 8),
        ),
        border: Border.all(
          color: isUser
              ? AppColors.neonViolet.withValues(alpha: 0.35)
              : AppColors.neonCyan.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF9BE7FF),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ),
  );
}
