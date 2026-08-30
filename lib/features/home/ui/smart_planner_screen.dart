import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _plannerUnavailableMessage =
    'Smart Planner is not enabled for this account yet. Your check-in was not saved or changed.';
const String _plannerRetryMessage =
    'Guidance could not be generated. Your check-in is still here. Tap GET GUIDANCE to retry.';

class SmartPlannerScreen extends ConsumerStatefulWidget {
  const SmartPlannerScreen({super.key});

  @override
  ConsumerState<SmartPlannerScreen> createState() => _SmartPlannerScreenState();
}

class _SmartPlannerScreenState extends ConsumerState<SmartPlannerScreen> {
  double? _energy;
  EmotionalState? _emotion;
  late final Future<void> Function() _stopVoice;
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _plannerResponseKey = GlobalKey();

  String? _planningGuidanceMessage;
  String? _planningGuidancePrompt;
  PlannerV2Response? _plannerResponse;
  OperatingDecisionReceipt? _operatingReceipt;
  String? _shownOperatingReceiptId;
  String? _followUpError;
  String? _guidanceError;
  String? _plannerActionStatus;
  final List<_Exchange> _followUps = [];
  bool _saved = false;
  bool _gettingPlanningGuidance = false;
  bool _sendingFollowUp = false;
  bool _showWhy = false;
  bool _showEvidence = false;

  List<_Exchange> get _visibleFollowUps {
    const int maxVisibleFollowUps = 20;
    if (_followUps.length <= maxVisibleFollowUps) {
      return _followUps;
    }
    return _followUps.sublist(_followUps.length - maxVisibleFollowUps);
  }

  @override
  void initState() {
    super.initState();
    final voiceService = ref.read(voiceServiceProvider);
    _stopVoice = voiceService.stop;
    final ConsentedHumanContext humanContext = ref.read(
      consentedHumanContextProvider,
    );
    _energy = humanContext.siState.hasObservedEnergy
        ? humanContext.siState.energy
        : null;
    _emotion = humanContext.emotion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _consumeFirstValueRequest();
    });
  }

  void _consumeFirstValueRequest() {
    final String accountScopeId =
        ref.read(accountStorageScopeProvider).v2Namespace ?? '';
    final SmartPlannerFirstValueRequest? request = ref
        .read(smartPlannerFirstValueProvider.notifier)
        .takeFor(accountScopeId: accountScopeId, now: DateTime.now().toUtc());
    if (request == null) return;

    setState(() {
      final String? prompt = request.prompt;
      if (prompt != null) _notesController.text = prompt;
      final double? energy = request.energy;
      if (energy != null) _energy = energy;
      _saved = false;
    });
    unawaited(_getPlanningGuidance());
  }

  @override
  void dispose() {
    unawaited(_stopVoice());
    _notesController.dispose();
    _followUpController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _getPlanningGuidance() async {
    if (_gettingPlanningGuidance) return;
    try {
      await _doGetPlanningGuidance();
    } on AssistantReleaseBlockedException {
      if (mounted) {
        setState(() {
          _gettingPlanningGuidance = false;
          _guidanceError = _plannerUnavailableMessage;
        });
      }
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'smart_planner',
        'Planning guidance failed.',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _gettingPlanningGuidance = false;
        _guidanceError = _plannerRetryMessage;
      });
    }
  }

  Future<void> _doGetPlanningGuidance() async {
    final String notes = _notesController.text.trim();
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    if (planner.detectsCrisis(notes) && mounted) {
      await showCrisisDialog(context);
      return;
    }

    setState(() {
      _gettingPlanningGuidance = true;
      _guidanceError = null;
    });

    final SmartPlannerResult result;
    try {
      result = await planner
          .requestPlanningGuidance(
            energy: _energy,
            emotion: _emotion,
            notes: notes,
            history: _conversationHistory(),
            previousSavedNotes: null,
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      if (!mounted) return;
      final SmartPlannerResult fallback = planner.localFallbackResult(
        input: notes.isEmpty ? 'quick check-in' : notes,
        message:
            'Guidance request timed out. Tap GET GUIDANCE again or shorten your input for a faster response.',
        energy: _energy,
        emotion: _emotion,
        history: _conversationHistory(),
        reason: 'request_timeout',
      );
      setState(() {
        _gettingPlanningGuidance = false;
        _planningGuidancePrompt = fallback.prompt;
        _planningGuidanceMessage = fallback.message;
        _plannerResponse = fallback.plannerResponse;
        _operatingReceipt = fallback.operatingReceipt;
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _planningGuidancePrompt = result.prompt;
      _planningGuidanceMessage = result.message;
      _plannerResponse = result.plannerResponse;
      _operatingReceipt = result.operatingReceipt;
      _guidanceError = null;
      _saved = true;
      _gettingPlanningGuidance = false;
      _plannerActionStatus = null;
      _showWhy = false;
      _showEvidence = false;
    });
    _recordOperatingReceiptShown(result.operatingReceipt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? responseContext = _plannerResponseKey.currentContext;
      if (responseContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          responseContext,
          alignment: 0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        ),
      );
    });
  }

  Future<void> _sendFollowUp() async {
    if (_sendingFollowUp) return;
    final String text = _followUpController.text.trim();
    if (text.isEmpty) return;
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    if (planner.detectsCrisis(text)) {
      if (!mounted) return;
      await showCrisisDialog(context);
      return;
    }
    _followUpController.clear();
    setState(() {
      _sendingFollowUp = true;
      _followUpError = null;
    });
    try {
      final SmartPlannerResult result = await planner
          .requestFollowUpResult(
            input: text,
            energy: _energy,
            emotion: _emotion,
            reflection: _notesController.text.trim(),
            history: _conversationHistory(),
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _followUps.add(_Exchange(question: text, answer: result.message));
        _plannerResponse = result.plannerResponse;
        _operatingReceipt = result.operatingReceipt;
        _showWhy = false;
        _showEvidence = false;
        _plannerActionStatus = null;
        _sendingFollowUp = false;
      });
      _recordOperatingReceiptShown(result.operatingReceipt);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = 'Follow-up timed out. Retry with a shorter prompt.';
      });
    } on AssistantReleaseBlockedException {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = _plannerUnavailableMessage;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = 'Follow-up transmit failed. Tap Retry Link.';
      });
      ErrorBoundary.of(context)?.captureError(error, stackTrace);
    }
  }

  void _useThisPlan() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;
    final CreatorDraftPreview draft = CreatorDraftPreview.fromPlannerResponse(
      response,
    );
    _recordOperatingOutcome(
      DecisionOutcomeKind.accepted,
      detail: 'Accepted through Smart Planner Use this plan.',
    );
    ref.read(creatorDraftPreviewProvider.notifier).stage(draft);
    goToAppView(context, ref, AppView.creator);
  }

  void _makeSmaller() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;
    final PlannerOption minimum =
        response.optionByKind[PlannerOptionKind.minimum]!;
    final PlannerV2Response smaller;
    if (response.recommendedKind == PlannerOptionKind.minimum) {
      final int minutes = (minimum.estimatedMinutes / 2).ceil().clamp(
        1,
        minimum.estimatedMinutes,
      );
      final PlannerOption reduced = minimum.copyWith(
        title: 'Smaller: ${minimum.title}',
        description:
            'Begin with a $minutes-minute setup step. ${minimum.description}',
        estimatedMinutes: minutes,
        tradeoff:
            'This reduces activation cost further and leaves more work for later.',
      );
      smaller = response.copyWith(
        options: <PlannerOption>[
          reduced,
          ...response.options.where(
            (PlannerOption option) => option.kind != PlannerOptionKind.minimum,
          ),
        ],
        nextStep: reduced.description,
        recommendationReason:
            'You asked for a smaller start, so this keeps only a brief setup step.',
      );
    } else {
      smaller = response.recommend(
        PlannerOptionKind.minimum,
        why:
            'You asked for a smaller plan, so the minimum option is now selected.',
      );
    }
    setState(() {
      _plannerResponse = smaller;
      _plannerActionStatus = 'The plan is smaller. Nothing has been saved.';
    });
    _recordOperatingOutcome(
      DecisionOutcomeKind.deferred,
      detail: 'Deferred the current receipt action by choosing Make smaller.',
    );
  }

  void _chooseDifferentApproach() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;
    final List<PlannerOptionKind> kinds = PlannerOptionKind.values;
    final int current = kinds.indexOf(response.recommendedKind);
    final PlannerOptionKind next = kinds[(current + 1) % kinds.length];
    setState(() {
      _plannerResponse = response.recommend(
        next,
        why:
            'You asked for a different approach, so another bounded option is selected.',
      );
      _plannerActionStatus =
          'A different approach is selected. Nothing has been saved.';
    });
    _recordOperatingOutcome(
      DecisionOutcomeKind.rejected,
      detail:
          'Rejected the current receipt approach by choosing Different approach.',
    );
  }

  void _recordOperatingReceiptShown(OperatingDecisionReceipt? receipt) {
    if (receipt == null ||
        receipt.isExpired ||
        _shownOperatingReceiptId == receipt.decisionId) {
      return;
    }
    _shownOperatingReceiptId = receipt.decisionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shownOperatingReceiptId != receipt.decisionId) return;
      unawaited(
        ref
            .read(decisionOutcomeActionsProvider)
            .record(
              receipt: receipt,
              kind: DecisionOutcomeKind.shown,
              surface: 'smart_planner',
              detail: 'Matched operating receipt shown in Planner V2.',
            ),
      );
    });
  }

  void _recordOperatingOutcome(
    DecisionOutcomeKind kind, {
    required String detail,
  }) {
    final OperatingDecisionReceipt? receipt = _operatingReceipt;
    if (receipt == null || receipt.isExpired) return;
    unawaited(
      ref
          .read(decisionOutcomeActionsProvider)
          .record(
            receipt: receipt,
            kind: kind,
            surface: 'smart_planner',
            detail: detail,
          ),
    );
  }

  Future<void> _rememberPreference() async {
    final TextEditingController preferenceController = TextEditingController();
    int retentionDays = 90;
    bool consentConfirmed = false;
    final _PreferenceMemoryChoice?
    choice = await showDialog<_PreferenceMemoryChoice>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setDialogState) {
          return AlertDialog(
            title: const Text('Remember a Smart Planner preference?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Use only this time is the default. Enter only the exact planning-style preference you want stored; your check-in, emotion, and response are not copied.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('planner-memory-preference-field'),
                    controller: preferenceController,
                    maxLength: 280,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Exact preference',
                      hintText:
                          'Example: Prefer one small next step before optional stretch ideas.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    key: const Key('planner-memory-expiry'),
                    initialValue: retentionDays,
                    decoration: const InputDecoration(
                      labelText: 'Automatically delete after',
                    ),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                      DropdownMenuItem(value: 90, child: Text('90 days')),
                      DropdownMenuItem(value: 180, child: Text('180 days')),
                      DropdownMenuItem(value: 365, child: Text('1 year')),
                    ],
                    onChanged: (int? value) {
                      if (value == null) return;
                      setDialogState(() => retentionDays = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.memoryAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Receipt preview\nWhy: save this preference for your review and future opt-in use\nRecall boundary: consented Smart Planner guidance only\nSource: Smart Planner only\nExpiry: $retentionDays days\nControls: view, correct, export, delete in Settings',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('planner-memory-consent'),
                    contentPadding: EdgeInsets.zero,
                    value: consentConfirmed,
                    title: const Text(
                      'I explicitly consent to storing this exact preference.',
                    ),
                    onChanged: (bool? value) =>
                        setDialogState(() => consentConfirmed = value ?? false),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Use only this time'),
              ),
              FilledButton(
                key: const Key('planner-confirm-memory'),
                onPressed: consentConfirmed
                    ? () => Navigator.of(dialogContext).pop(
                        _PreferenceMemoryChoice(
                          text: preferenceController.text,
                          retentionDays: retentionDays,
                        ),
                      )
                    : null,
                child: const Text('Remember preference'),
              ),
            ],
          );
        },
      ),
    );
    preferenceController.dispose();
    if (choice == null || !mounted) {
      if (choice == null && mounted) {
        setState(() {
          _plannerActionStatus =
              'Used only for this check-in. No durable memory was saved.';
        });
      }
      return;
    }

    final DateTime expiresAt = DateTime.now().toUtc().add(
      Duration(days: choice.retentionDays),
    );
    try {
      final MemoryReceipt receipt = await ref
          .read(memoryGovernanceControllerProvider)
          .rememberPreference(
            text: choice.text,
            sourceSurface: MemorySurface.smartPlanner,
            expiresAt: expiresAt,
            consentConfirmed: true,
            whyStored:
                'Save this explicit planning-style preference for review and future opt-in use.',
            provenance: 'User-entered in Smart Planner memory consent dialog.',
          );
      if (!mounted) return;
      final String expiry = receipt.expiresAt!
          .toLocal()
          .toIso8601String()
          .split('T')
          .first;
      setState(() {
        _plannerActionStatus =
            'Preference saved with consent. Recall stays limited to Smart Planner guidance · expires $expiry · manage in Settings.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _plannerActionStatus = error.toString());
    }
  }

  List<Map<String, String>> _conversationHistory() {
    final List<Map<String, String>> history = <Map<String, String>>[];
    final String initialPrompt = _planningGuidancePrompt?.trim() ?? '';
    final String initialResponse = _planningGuidanceMessage?.trim() ?? '';
    if (initialPrompt.isNotEmpty) {
      history.add(<String, String>{'role': 'user', 'content': initialPrompt});
    }
    if (initialResponse.isNotEmpty) {
      history.add(<String, String>{
        'role': 'assistant',
        'content': initialResponse,
      });
    }
    for (final _Exchange exchange in _followUps) {
      history
        ..add(<String, String>{'role': 'user', 'content': exchange.question})
        ..add(<String, String>{
          'role': 'assistant',
          'content': exchange.answer,
        });
    }
    return history.length > 8 ? history.sublist(history.length - 8) : history;
  }

  @override
  Widget build(BuildContext context) {
    final ConsentedHumanContext humanContext = ref.watch(
      consentedHumanContextProvider,
    );
    final PlannerV2Response? plannerResponse = _plannerResponse;
    final String effectivePlannerMessage =
        plannerResponse?.toAccessibleText() ?? '';
    final bool hasPlannerMessage = plannerResponse != null;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgHome,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    hasPlannerMessage ? 20 : 12,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    TemporalGlassSurface(
                      accent: AppColors.neonCyan,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'CURRENT CHECK-IN',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppColors.neonCyan,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 14),
                          _EnergySlider(
                            value: _energy,
                            color: AppColors.neonCyan,
                            onChanged: (v) => setState(() {
                              _energy = v;
                              _saved = false;
                            }),
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          Text(
                            'EMOTIONAL STATE',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.neonViolet,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 10),
                          _EmotionStateControl(
                            selected: _emotion,
                            onSelect: (e) => setState(() {
                              _emotion = e;
                              _saved = false;
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            humanContext.emotionAllowed
                                ? 'Only the state you select is used for this check-in.'
                                : 'Emotional state is not used. Enable it in Settings to include a selection.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          Text(
                            'PLANNING CONTEXT',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.neonCyan,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            label: 'Planning context',
                            textField: true,
                            child: TextField(
                              key: const Key('planner-context-field'),
                              controller: _notesController,
                              minLines: 3,
                              maxLines: 5,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5,
                                letterSpacing: 0,
                              ),
                              decoration: const InputDecoration(
                                hintText:
                                    'What would you like help planning right now?',
                                hintStyle: TextStyle(
                                  color: Color(0xFFAEB9D0),
                                  fontSize: 16,
                                  height: 1.5,
                                  letterSpacing: 0,
                                ),
                                contentPadding: EdgeInsets.all(16),
                              ),
                              onChanged: (_) {
                                if (_saved) {
                                  setState(() => _saved = false);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your words and check-in stay ephemeral. A local decision receipt may record which guidance was shown or used. Nothing else is saved unless you explicitly remember a preference.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.45,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TemporalActionButton(
                      label: _gettingPlanningGuidance
                          ? 'THINKING...'
                          : (_saved ? 'REFRESH GUIDANCE' : 'GET GUIDANCE'),
                      accent: AppColors.neonCyan,
                      icon: Icons.auto_awesome_rounded,
                      onPressed: _gettingPlanningGuidance
                          ? null
                          : _getPlanningGuidance,
                    ),
                    if (_guidanceError != null) ...[
                      const SizedBox(height: 12),
                      TemporalGlassSurface(
                        key: const Key('planner-guidance-unavailable'),
                        accent: AppColors.recallRed,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.recallRed,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _guidanceError!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (hasPlannerMessage) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        key: _plannerResponseKey,
                        container: true,
                        liveRegion: true,
                        label: 'Planning guidance ready',
                        child: _PlannerV2ResponsePanel(
                          response: plannerResponse,
                          actionStatus: _plannerActionStatus,
                          showWhy: _showWhy,
                          showEvidence: _showEvidence,
                          onUseThisPlan: _useThisPlan,
                          onMakeSmaller: _makeSmaller,
                          onDifferentApproach: _chooseDifferentApproach,
                          onToggleWhy: () => setState(() {
                            _showWhy = !_showWhy;
                          }),
                          onToggleEvidence: () => setState(() {
                            _showEvidence = !_showEvidence;
                          }),
                          onRememberPreference: () =>
                              unawaited(_rememberPreference()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _VoiceButton(message: effectivePlannerMessage),
                          _VoiceSummaryButton(
                            headline: effectivePlannerMessage,
                            energy: _energy,
                            emotion: _emotion,
                          ),
                          const _VoiceAccessibilityButton(),
                          _MicButton(
                            onRecognized: (String text) =>
                                _followUpController.text = text,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._visibleFollowUps.map(
                        (ex) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _bubble(ex.question, isUser: true),
                              const SizedBox(height: 6),
                              _bubble(ex.answer, isUser: false),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const _DisclaimerText(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: hasPlannerMessage
            ? AnimatedPadding(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: _FollowUpBar(
                  controller: _followUpController,
                  onSend: _sendFollowUp,
                  sending: _sendingFollowUp,
                  errorText: _followUpError,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader() {
    return TemporalScreenHeader(
      title: 'Smart Planner',
      subtitle: 'Build your next plan from real evidence.',
      eyebrow: 'Plan spectrum',
      onBack: () => goToAppView(context, ref, AppView.nexus),
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
}

class _Exchange {
  const _Exchange({required this.question, required this.answer});
  final String question;
  final String answer;
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
            text: 'ON-DEVICE PLANNER V2 · DETERMINISTIC · NOT AI-GENERATED',
            color: AppColors.neonCyan,
          ),
          if (response.isClarification) ...[
            _section('WHAT I HEARD', _body(response.whatIHeard)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Audio is unavailable. Check text-to-speech settings and media volume.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _reading
          ? 'Reading full planning guidance aloud'
          : 'Read full planning guidance aloud',
      button: true,
      child: GestureDetector(
        onTap: _reading ? null : () => unawaited(_readAloud()),
        behavior: HitTestBehavior.opaque,
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
                _reading ? 'READING' : 'READ ALOUD',
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
    return Semantics(
      label: 'Read condensed planning summary aloud',
      button: true,
      child: GestureDetector(
        onTap: () => unawaited(
          ref
              .read(voiceServiceProvider)
              .speakSummary(
                title: 'Smart Planner voice summary',
                points: <String>[
                  energy == null
                      ? 'Energy was not set'
                      : 'Energy is ${(energy! * 100).round()} percent',
                  emotion == null
                      ? 'Emotional state was not used'
                      : 'Emotion state is ${emotion!.name}',
                  headline,
                ],
              ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.neonCyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.45),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.summarize_rounded,
                color: AppColors.neonCyan,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'SUMMARY',
                style: TextStyle(
                  color: AppColors.neonCyan,
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

class _VoiceAccessibilityButton extends ConsumerWidget {
  const _VoiceAccessibilityButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Open Smart Planner accessibility guide and read it aloud',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: const Color(0xFF0D1420),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            builder: (BuildContext context) {
              return const SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Accessibility Guide',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'A11Y means accessibility. Use these controls for easier reading and audio guidance.',
                          style: TextStyle(
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
          );
          unawaited(
            ref
                .read(voiceServiceProvider)
                .speakAccessibilityHint(
                  surface: 'Smart Planner',
                  controls: const <String>[
                    'Adjust energy slider to set intensity',
                    'Select emotional state to tune guidance',
                    'Use Get Guidance to generate a planning response',
                    'Use the speak button to read the latest guidance aloud',
                    'Use summary button for condensed voice recap',
                    'Use microphone button for voice interactions',
                  ],
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                color: Colors.white70,
                size: 15,
              ),
              SizedBox(width: 5),
              Text(
                'ACCESS',
                style: TextStyle(
                  color: Colors.white70,
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

class _MicButton extends ConsumerWidget {
  const _MicButton({required this.onRecognized});

  final ValueChanged<String> onRecognized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      label: listening ? 'Stop voice input' : 'Start voice input',
      button: true,
      liveRegion: listening,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Voice input is unavailable. Check permission and retry.',
                ),
              ),
            );
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
                listening ? 'LISTENING' : 'VOICE INPUT',
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
