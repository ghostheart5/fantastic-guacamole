import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:fantastic_guacamole/ui/widgets/dropdown_route_keyboard_guard.dart';
import 'dart:async';

import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/decision_outcome_entity.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/domain/entities/planner_explanation_contract.dart';
import 'package:fantastic_guacamole/domain/learning/learning_ledger.dart';
import 'package:fantastic_guacamole/domain/operating_system/operating_system_contract.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/features/home/ui/first_use_context_offer_card.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/features/permissions/voice_input_consent.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/planner_explanation_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:fantastic_guacamole/ui/widgets/text_controller_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'smart_planner_screen.widgets.dart';
part 'smart_planner_screen.consent_copy.dart';

class SmartPlannerScreen extends ConsumerStatefulWidget {
  const SmartPlannerScreen({super.key});

  @override
  ConsumerState<SmartPlannerScreen> createState() => _SmartPlannerScreenState();
}

class _SmartPlannerScreenState extends ConsumerState<SmartPlannerScreen> {
  double? _energy;
  int _checkInRevision = 0;
  EmotionalState? get _emotion => ref.read(currentPlannerEmotionProvider);
  late final Future<void> Function() _stopVoice;
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  String _followUpDictationBase = '';
  final ScrollController _scroll = ScrollController();
  final GlobalKey _plannerResponseKey = GlobalKey();

  String? _planningGuidanceMessage;
  String? _planningGuidancePrompt;
  PlannerV2Response? _plannerResponse;
  PlannerOption? _baseMinimumOption;
  final List<PlannerAdjustment> _planAdjustments = <PlannerAdjustment>[];
  bool _awaitingApproachReason = false;
  String? _plannerPersonContextBehaviorRevision;
  String? _plannerPersonContextDecisionText;
  OperatingDecisionReceipt? _operatingReceipt;
  String? _shownOperatingReceiptId;
  String? _followUpError;
  String? _failedFollowUpText;
  String? _guidanceError;
  String? _plannerActionStatus;
  String? _plannerExplanationError;
  PlannerExplanationPacket? _pendingExplanationPacket;
  PlannerExplanationQuote? _pendingExplanationQuote;
  PlannerExplanationResult? _plannerExplanationResult;
  final List<_Exchange> _followUps = [];
  bool _saved = false;
  bool _gettingPlanningGuidance = false;
  bool _sendingFollowUp = false;
  bool _showWhy = false;
  bool _showEvidence = false;
  bool _requestingPlannerExplanation = false;
  bool _showFirstUseContextOffer = false;

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
      _clearPlannerExplanationState();
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
    if (_gettingPlanningGuidance || _sendingFollowUp) return;
    final int revision = _checkInRevision;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _gettingPlanningGuidance = true;
      _guidanceError = null;
    });
    try {
      await _doGetPlanningGuidance();
    } on AssistantReleaseBlockedException {
      if (mounted && revision == _checkInRevision) {
        setState(() {
          _gettingPlanningGuidance = false;
          _guidanceError = ChronoSparkLocalizations.of(
            context,
          ).plannerRoutine.guidanceUnavailable;
        });
      }
    } catch (error, stackTrace) {
      Logger.errorCategory(
        'smart_planner',
        'Planning guidance failed.',
        error,
        stackTrace,
      );
      if (!mounted || revision != _checkInRevision) return;
      setState(() {
        _gettingPlanningGuidance = false;
        _guidanceError = ChronoSparkLocalizations.of(
          context,
        ).plannerRoutine.guidanceRetry;
      });
    } finally {
      if (mounted && revision == _checkInRevision && _gettingPlanningGuidance) {
        setState(() => _gettingPlanningGuidance = false);
      }
    }
  }

  Future<void> _doGetPlanningGuidance() async {
    final revision = _checkInRevision;
    final String notes = _notesController.text.trim();
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    if (!await _confirmEmotionalSafetyRoute(notes, planner)) {
      return;
    }
    if (!mounted || revision != _checkInRevision) return;
    final ({String? pauseReason, String? question}) supportiveCopy =
        _localizedSupportiveCopy(notes, planner);

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
            languageCode: ChronoSparkLocalizations.of(context).isSpanish
                ? 'es'
                : 'en',
            supportivePauseReason: supportiveCopy.pauseReason,
            supportiveQuestion: supportiveCopy.question,
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      if (!mounted || revision != _checkInRevision) return;
      final SmartPlannerResult fallback = planner.localFallbackResult(
        input: notes.isEmpty
            ? (ChronoSparkLocalizations.of(context).isSpanish
                  ? 'registro rápido'
                  : 'quick check-in')
            : notes,
        message: ChronoSparkLocalizations.of(
          context,
        ).plannerRoutine.guidanceTimeout,
        energy: _energy,
        emotion: _emotion,
        history: _conversationHistory(),
        reason: 'request_timeout',
        supportivePauseReason: supportiveCopy.pauseReason,
        supportiveQuestion: supportiveCopy.question,
        languageCode: ChronoSparkLocalizations.of(context).isSpanish
            ? 'es'
            : 'en',
      );
      final PlannerV2Response effectiveResponse = _applyReviewableLearning(
        fallback.plannerResponse,
      );
      final bool showContextOffer =
          !effectiveResponse.isClarification &&
          await _claimFirstUseContextOffer();
      if (!mounted || revision != _checkInRevision) return;
      setState(() {
        _gettingPlanningGuidance = false;
        _planningGuidancePrompt = fallback.prompt;
        _planningGuidanceMessage = fallback.message;
        _plannerResponse = effectiveResponse;
        _resetPlanAdjustments(effectiveResponse);
        _plannerPersonContextDecisionText = fallback.prompt;
        _plannerPersonContextBehaviorRevision = ref.read(
          smartPlannerPersonContextBehaviorRevisionForDecisionProvider(
            fallback.prompt,
          ),
        );
        _operatingReceipt = fallback.operatingReceipt;
        _showFirstUseContextOffer = showContextOffer;
        _clearPlannerExplanationState();
      });
      return;
    }
    if (!mounted || revision != _checkInRevision) return;
    final PlannerV2Response effectiveResponse = _applyReviewableLearning(
      result.plannerResponse,
    );
    final bool showContextOffer =
        !effectiveResponse.isClarification &&
        await _claimFirstUseContextOffer();
    if (!mounted || revision != _checkInRevision) return;

    setState(() {
      _planningGuidancePrompt = result.prompt;
      _planningGuidanceMessage = result.message;
      _plannerResponse = effectiveResponse;
      _resetPlanAdjustments(effectiveResponse);
      _plannerPersonContextDecisionText = result.prompt;
      _plannerPersonContextBehaviorRevision = _personContextBehaviorRevisionFor(
        result,
      );
      _operatingReceipt = result.operatingReceipt;
      _guidanceError = null;
      _saved = true;
      _gettingPlanningGuidance = false;
      _plannerActionStatus = null;
      _showWhy = false;
      _showEvidence = false;
      _showFirstUseContextOffer = showContextOffer;
      _clearPlannerExplanationState();
    });
    _recordOperatingReceiptShown(result.operatingReceipt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _checkInRevision) return;
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

  PlannerV2Response _applyReviewableLearning(PlannerV2Response response) {
    if (ref.read(learningPausedProvider).asData?.value != false) {
      return response;
    }
    return applyPlannerLearnedPreference(
      response,
      ref.read(learningLedgerSummaryProvider),
    );
  }

  Future<bool> _claimFirstUseContextOffer() async {
    try {
      return await ref.read(firstUseContextOfferActionsProvider).claim();
    } on Object {
      return false;
    }
  }

  Future<void> _addFirstUseGoalContext() async {
    final _SmartPlannerConsentCopy copy = _SmartPlannerConsentCopy.of(context);
    bool consent = false;
    final String? exactText = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => TextControllerScope(
        builder: (dialogContext, controllers) {
          final controller = controllers[0];
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) =>
                AlertDialog(
                  title: Text(copy.priorityTitle),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(copy.priorityIntroduction),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('first-use-context-value'),
                          controller: controller,
                          maxLength: 280,
                          minLines: 2,
                          maxLines: 4,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: copy.priorityLabel,
                            hintText: copy.priorityHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          copy.priorityDisclosure,
                          style: const TextStyle(height: 1.45),
                        ),
                        CheckboxListTile(
                          key: const Key('first-use-context-consent'),
                          contentPadding: EdgeInsets.zero,
                          value: consent,
                          title: Text(copy.priorityConsent),
                          onChanged: (bool? value) =>
                              setDialogState(() => consent = value ?? false),
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(copy.useOnlyThisTime),
                    ),
                    FilledButton(
                      key: const Key('first-use-context-confirm'),
                      onPressed: consent && controller.text.trim().isNotEmpty
                          ? () => Navigator.of(
                              dialogContext,
                            ).pop(controller.text.trim())
                          : null,
                      child: Text(copy.saveWithConsent),
                    ),
                  ],
                ),
          );
        },
      ),
    );
    if (exactText == null || !mounted) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    try {
      await ref
          .read(personContextActionsProvider)
          .upsert(
            PersonContextSignal(
              id: 'first-goal-context-${now.microsecondsSinceEpoch}',
              kind: PersonContextKind.currentPriority,
              value: exactText,
              source: PersonContextSource.userAuthored,
              consent: PersonContextConsent.granted,
              consentedAt: now,
              purpose: PersonContextPurpose.decisionSupport,
              surfaceScopes: const <PersonContextSurface>{
                PersonContextSurface.smartPlanner,
              },
              recordedAt: now,
              freshUntil: now.add(const Duration(days: 30)),
              expiresAt: now.add(const Duration(days: 30)),
              exportBehavior: PersonContextExportBehavior.include,
              deletionBehavior:
                  PersonContextDeletionBehavior.expiresAutomatically,
            ),
          );
      if (!mounted) return;
      setState(() {
        _showFirstUseContextOffer = false;
        _plannerActionStatus = copy.prioritySaved;
      });
    } on Object catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.plannerPersonContextSaveFailed,
        debugMessage: 'Optional Planner context could not be saved.',
        exception: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final PublicFailure failure = PublicFailure.from(
        error,
        fallback: copy.contextSaveFailed,
        isSpanish: copy.isSpanish,
      );
      setState(() => _plannerActionStatus = failure.message);
    }
  }

  Future<void> _retryFollowUp() async {
    final String? failedText = _failedFollowUpText;
    if (failedText == null) return;
    await _sendFollowUp(requestText: failedText);
  }

  Future<void> _sendFollowUp({String? requestText}) async {
    if (_sendingFollowUp || _gettingPlanningGuidance) return;
    final revision = _checkInRevision;
    final String text = requestText ?? _followUpController.text.trim();
    if (text.isEmpty) return;
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    final history = _conversationHistory();
    final reflection = _notesController.text.trim();
    final PlannerV2Response? displayedPlan = _plannerResponse;
    final PlannerConversationSnapshot? currentPlan = displayedPlan == null
        ? null
        : PlannerConversationSnapshot(
            originalObjective: _planningGuidancePrompt ?? reflection,
            currentPlan: displayedPlan,
            userContext: displayedPlan.userContext,
            adjustments: List<PlannerAdjustment>.of(_planAdjustments),
          );
    final safetyText = planner.followUpSafetyText(
      input: text,
      reflection: reflection,
      history: history,
    );
    setState(() => _sendingFollowUp = true);
    if (!await _confirmEmotionalSafetyRoute(safetyText, planner)) {
      if (mounted && revision == _checkInRevision) {
        setState(() => _sendingFollowUp = false);
      }
      return;
    }
    if (!mounted || revision != _checkInRevision) return;
    final supportiveCopy = _localizedSupportiveCopy(safetyText, planner);
    _followUpController.clear();
    setState(() {
      _sendingFollowUp = true;
      _followUpError = null;
      _failedFollowUpText = null;
    });
    try {
      final SmartPlannerResult result = await planner
          .requestFollowUpResult(
            input: text,
            energy: _energy,
            emotion: _emotion,
            reflection: reflection,
            history: history,
            currentPlan: currentPlan,
            languageCode: ChronoSparkLocalizations.of(context).isSpanish
                ? 'es'
                : 'en',
            supportivePauseReason: supportiveCopy.pauseReason,
            supportiveQuestion: supportiveCopy.question,
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted || revision != _checkInRevision) return;
      setState(() {
        _followUps.add(
          _Exchange(
            question: text,
            answer: result.plannerResponse.toConversationText(),
          ),
        );
        _plannerResponse = result.plannerResponse;
        _resetPlanAdjustments(result.plannerResponse);
        _plannerPersonContextDecisionText = result.prompt;
        _plannerPersonContextBehaviorRevision =
            _personContextBehaviorRevisionFor(result);
        _operatingReceipt = result.operatingReceipt;
        _showWhy = false;
        _showEvidence = false;
        _plannerActionStatus = null;
        _clearPlannerExplanationState();
        _sendingFollowUp = false;
        _failedFollowUpText = null;
      });
      _recordOperatingReceiptShown(result.operatingReceipt);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          unawaited(
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            ),
          );
        }
      });
    } on TimeoutException {
      if (!mounted || revision != _checkInRevision) return;
      setState(() {
        _sendingFollowUp = false;
        _restoreFailedFollowUp(text);
        _followUpError = ChronoSparkLocalizations.of(
          context,
        ).plannerRoutine.followUpTimeout;
      });
    } on AssistantReleaseBlockedException {
      if (!mounted || revision != _checkInRevision) return;
      setState(() {
        _sendingFollowUp = false;
        _restoreFailedFollowUp(text);
        _followUpError = ChronoSparkLocalizations.of(
          context,
        ).plannerRoutine.guidanceUnavailable;
      });
    } catch (error, stackTrace) {
      if (!mounted || revision != _checkInRevision) return;
      setState(() {
        _sendingFollowUp = false;
        _restoreFailedFollowUp(text);
        _followUpError = ChronoSparkLocalizations.of(
          context,
        ).plannerRoutine.followUpTransmitFailed;
      });
      Logger.errorCategory(
        'smart_planner',
        'Follow-up failed; the request is retained for retry.',
        error,
        stackTrace,
      );
    }
  }

  void _restoreFailedFollowUp(String text) {
    _failedFollowUpText = text;
    if (_followUpController.text.isEmpty) _followUpController.text = text;
  }

  void _resetPlanAdjustments(PlannerV2Response response) {
    _baseMinimumOption = response.optionByKind[PlannerOptionKind.minimum];
    _planAdjustments.clear();
    _awaitingApproachReason = false;
  }

  Future<bool> _confirmEmotionalSafetyRoute(
    String input,
    SmartPlannerQueryController planner,
  ) async {
    if (planner.detectsCrisis(input)) {
      if (mounted) await showCrisisDialog(context);
      return false;
    }
    final EmotionalSafetyAssessment assessment = planner.assessEmotionalSafety(
      input,
    );
    if (assessment.route == EmotionalSafetyRoute.routine) return true;
    if (!mounted) return false;
    final SupportiveDistressChoice choice = await showSupportiveDistressDialog(
      context,
    );
    return mounted &&
        choice == SupportiveDistressChoice.continueWithGentleQuestion;
  }

  ({String? pauseReason, String? question}) _localizedSupportiveCopy(
    String input,
    SmartPlannerQueryController planner,
  ) {
    final EmotionalSafetyAssessment assessment = planner.assessEmotionalSafety(
      input,
    );
    if (!assessment.requiresSupportivePause) {
      return (pauseReason: null, question: null);
    }
    final ChronoSparkLocalizations l10n = ChronoSparkLocalizations.of(context);
    return (
      pauseReason: l10n.emotionalSafetyPauseReason(assessment.pauseReasonCode),
      question: l10n.emotionalSafetySupportQuestion(
        assessment.supportQuestionCode,
      ),
    );
  }

  void _useThisPlan() {
    if (_sendingFollowUp || _gettingPlanningGuidance) return;
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;
    final CreatorDraftPreview draft = CreatorDraftPreview.fromPlannerResponse(
      response,
    );
    _recordOperatingOutcome(
      DecisionOutcomeKind.accepted,
      detail: 'Accepted through Smart Planner Use this plan.',
      optionChosen: response.recommendedKind.name,
      optionSizeMinutes:
          response.optionByKind[response.recommendedKind]?.estimatedMinutes,
      recommendationHelped: null,
    );
    ref.read(creatorHandshakeProvider.notifier).clearResult();
    ref.read(creatorDraftPreviewProvider.notifier).stage(draft);
    goToAppView(context, ref, AppView.creator);
  }

  String _personContextBehaviorRevisionFor(SmartPlannerResult result) {
    final Object? boundRevision =
        result.request.context['personContextBehaviorRevision'];
    return boundRevision is String && boundRevision.trim().isNotEmpty
        ? boundRevision
        : ref.read(
            smartPlannerPersonContextBehaviorRevisionForDecisionProvider(
              result.prompt,
            ),
          );
  }

  void _invalidatePlannerOutputForPersonContext(String currentRevision) {
    final String? boundRevision = _plannerPersonContextBehaviorRevision;
    if (!mounted ||
        _plannerResponse == null ||
        boundRevision == null ||
        boundRevision == currentRevision) {
      return;
    }
    _clearChangedCheckIn();
    setState(() {
      _plannerPersonContextDecisionText = null;
      _plannerPersonContextBehaviorRevision = currentRevision;
      _operatingReceipt = null;
      _shownOperatingReceiptId = null;
      _followUps.clear();
      _followUpError = null;
      _plannerActionStatus = null;
      _guidanceError = ChronoSparkLocalizations.of(
        context,
      ).plannerRoutine.personContextChanged;
      _saved = false;
      _showFirstUseContextOffer = false;
      _showWhy = false;
      _showEvidence = false;
      _clearPlannerExplanationState();
    });
  }

  void _clearChangedCheckIn() {
    if (!mounted) return;
    unawaited(_stopVoice());
    setState(() {
      _checkInRevision++;
      _plannerResponse = null;
      _baseMinimumOption = null;
      _planAdjustments.clear();
      _awaitingApproachReason = false;
      _planningGuidanceMessage = null;
      _planningGuidancePrompt = null;
      _followUps.clear();
      _followUpController.clear();
      _followUpError = null;
      _failedFollowUpText = null;
      _sendingFollowUp = false;
      _gettingPlanningGuidance = false;
      _operatingReceipt = null;
      _shownOperatingReceiptId = null;
      _plannerActionStatus = null;
      _guidanceError = null;
      _saved = false;
      _showFirstUseContextOffer = false;
      _showWhy = false;
      _showEvidence = false;
      _clearPlannerExplanationState();
    });
  }

  void _makeSmaller() {
    if (_sendingFollowUp || _gettingPlanningGuidance) return;
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    final PlannerOption minimum =
        response.optionByKind[PlannerOptionKind.minimum]!;
    final PlannerOption base = _baseMinimumOption ?? minimum;
    final int previousMinutes =
        response.optionByKind[response.recommendedKind]!.estimatedMinutes;
    final PlannerV2Response smaller;
    if (response.recommendedKind == PlannerOptionKind.minimum) {
      if (minimum.estimatedMinutes <= 1) {
        setState(() => _plannerActionStatus = copy.minimumReachedStatus);
        return;
      }
      final int minutes = (minimum.estimatedMinutes / 2).ceil().clamp(
        1,
        minimum.estimatedMinutes,
      );
      final PlannerOption reduced = base.copyWith(
        // Keep the original atomic action. Wrapping the previous response
        // accumulates old durations and increases the work as time shrinks.
        description: base.description,
        estimatedMinutes: minutes,
        tradeoff: copy.smallerTradeoff,
      );
      smaller = response.copyWith(
        options: <PlannerOption>[
          reduced,
          ...response.options.where(
            (PlannerOption option) => option.kind != PlannerOptionKind.minimum,
          ),
        ],
        nextStep: reduced.description,
        recommendationReason: copy.smallerReason,
      );
    } else {
      smaller = response.recommend(
        PlannerOptionKind.minimum,
        why: copy.minimumSelectedReason,
      );
    }
    setState(() {
      _plannerResponse = smaller;
      _planAdjustments.add(
        PlannerAdjustment(
          kind: PlannerAdjustmentKind.smaller,
          description: 'The user chose Make smaller for the displayed plan.',
          previousMinutes: previousMinutes,
          currentMinutes:
              smaller.optionByKind[smaller.recommendedKind]!.estimatedMinutes,
        ),
      );
      _awaitingApproachReason = false;
      _plannerActionStatus = copy.smallerStatus;
      _clearPlannerExplanationState();
    });
    _recordOperatingOutcome(
      DecisionOutcomeKind.deferred,
      detail: 'Deferred the current receipt action by choosing Make smaller.',
      optionChosen: smaller.recommendedKind.name,
      optionSizeMinutes:
          smaller.optionByKind[smaller.recommendedKind]?.estimatedMinutes,
      deferralReason: 'Asked for a smaller next step.',
    );
  }

  void _chooseDifferentApproach() {
    if (_sendingFollowUp || _gettingPlanningGuidance) return;
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;
    final PlannerRoutineCopy copy = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    if (_awaitingApproachReason) return;
    final PlannerOptionKind rejected = response.recommendedKind;
    setState(() {
      _plannerResponse = response.copyWith(clearUsefulQuestion: true);
      _planAdjustments.add(
        PlannerAdjustment(
          kind: PlannerAdjustmentKind.rejectedApproach,
          description:
              'The user rejected the displayed approach; the reason is not known yet.',
          previousMinutes: response.optionByKind[rejected]!.estimatedMinutes,
          currentMinutes: response.optionByKind[rejected]!.estimatedMinutes,
        ),
      );
      _awaitingApproachReason = true;
      _plannerActionStatus = copy.differentApproachQuestion;
      _clearPlannerExplanationState();
    });
    _recordOperatingOutcome(
      DecisionOutcomeKind.rejected,
      detail:
          'Rejected the current receipt approach by choosing Different approach.',
      optionChosen: rejected.name,
      optionSizeMinutes: response.optionByKind[rejected]?.estimatedMinutes,
      recommendationHelped: false,
    );
  }

  void _recordOperatingReceiptShown(OperatingDecisionReceipt? receipt) {
    if (receipt == null ||
        receipt.isExpired ||
        _shownOperatingReceiptId == receipt.decisionId) {
      return;
    }
    final PlannerV2Response? shownResponse = _plannerResponse;
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
              situation: 'bounded planning choice',
              optionChosen: shownResponse?.recommendedKind.name,
              optionSizeMinutes: shownResponse == null
                  ? null
                  : shownResponse
                        .optionByKind[shownResponse.recommendedKind]
                        ?.estimatedMinutes,
            ),
      );
    });
  }

  void _recordOperatingOutcome(
    DecisionOutcomeKind kind, {
    required String detail,
    String? optionChosen,
    int? optionSizeMinutes,
    String? deferralReason,
    bool? recommendationHelped,
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
            situation: 'bounded planning choice',
            optionChosen: optionChosen,
            optionSizeMinutes: optionSizeMinutes,
            deferralReason: deferralReason,
            recommendationHelped: recommendationHelped,
          ),
    );
  }

  Future<void> _rememberPreference() async {
    final _SmartPlannerConsentCopy copy = _SmartPlannerConsentCopy.of(context);
    int retentionDays = 90;
    bool consentConfirmed = false;
    final _PreferenceMemoryChoice?
    choice = await showDialog<_PreferenceMemoryChoice>(
      context: context,
      builder: (BuildContext dialogContext) => TextControllerScope(
        builder: (dialogContext, controllers) {
          final preferenceController = controllers[0];
          return StatefulBuilder(
            builder:
                (
                  BuildContext context,
                  void Function(void Function()) setDialogState,
                ) {
                  return AlertDialog(
                    title: Text(copy.preferenceTitle),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(copy.preferenceIntroduction),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('planner-memory-preference-field'),
                            controller: preferenceController,
                            maxLength: 280,
                            minLines: 2,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: copy.preferenceLabel,
                              hintText: copy.preferenceHint,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownRouteKeyboardGuard(
                            child: DropdownButtonFormField<int>(
                              key: const Key('planner-memory-expiry'),
                              initialValue: retentionDays,
                              decoration: InputDecoration(
                                labelText: copy.deleteAfter,
                              ),
                              items: <DropdownMenuItem<int>>[
                                for (final int days in <int>[30, 90, 180, 365])
                                  DropdownMenuItem(
                                    value: days,
                                    child: Text(copy.retentionLabel(days)),
                                  ),
                              ],
                              onChanged: (int? value) {
                                if (value == null) return;
                                setDialogState(() => retentionDays = value);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.memoryAmber.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              copy.receiptPreview(retentionDays),
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                          CheckboxListTile(
                            key: const Key('planner-memory-consent'),
                            contentPadding: EdgeInsets.zero,
                            value: consentConfirmed,
                            title: Text(copy.preferenceConsent),
                            onChanged: (bool? value) => setDialogState(
                              () => consentConfirmed = value ?? false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(copy.useOnlyThisTime),
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
                        child: Text(copy.rememberPreference),
                      ),
                    ],
                  );
                },
          );
        },
      ),
    );
    if (choice == null || !mounted) {
      if (choice == null && mounted) {
        setState(() {
          _plannerActionStatus = copy.usedOnce;
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
        _plannerActionStatus = copy.preferenceSaved(expiry);
      });
    } on Object catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.plannerPreferenceSaveFailed,
        debugMessage: 'Planner preference could not be saved.',
        exception: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final PublicFailure failure = PublicFailure.from(
        error,
        fallback: copy.preferenceSaveFailed,
        isSpanish: copy.isSpanish,
      );
      setState(() => _plannerActionStatus = failure.message);
    }
  }

  void _clearPlannerExplanationState() {
    _pendingExplanationPacket = null;
    _pendingExplanationQuote = null;
    _plannerExplanationResult = null;
    _plannerExplanationError = null;
    _requestingPlannerExplanation = false;
  }

  Future<void> _requestPlannerExplanation() async {
    if (_requestingPlannerExplanation) return;
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return;

    final PlannerExplanationAvailability availability = await ref.read(
      plannerExplanationAvailabilityProvider.future,
    );
    if (!mounted || availability != PlannerExplanationAvailability.available) {
      return;
    }

    final PlannerExplanationPacket packet;
    try {
      packet = PlannerExplanationPacket.fromPlannerResponse(response);
      packet.validateForExternalProcessing();
    } on Object {
      if (!mounted) return;
      setState(() {
        _plannerExplanationError =
            'This plan cannot be sent for external explanation. Your deterministic plan is unchanged.';
      });
      return;
    }

    setState(() {
      _requestingPlannerExplanation = true;
      _plannerExplanationError = null;
      _plannerExplanationResult = null;
      _pendingExplanationPacket = null;
      _pendingExplanationQuote = null;
    });

    try {
      final PlannerExplanationPort port = await ref.read(
        plannerExplanationPortProvider.future,
      );
      final PlannerExplanationQuote quote = await port.quote(packet);
      if (!mounted || !_plannerResponseMatches(packet)) return;
      setState(() {
        _requestingPlannerExplanation = false;
        _pendingExplanationPacket = packet;
        _pendingExplanationQuote = quote;
      });
      final bool approved = await _confirmPlannerExplanationQuote(quote);
      if (!mounted) return;
      if (!approved) {
        setState(() {
          _pendingExplanationPacket = null;
          _pendingExplanationQuote = null;
        });
        return;
      }
      await _executePlannerExplanation(packet: packet, quote: quote);
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'planner_explanation',
        'Optional Planner explanation quote failed.',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _requestingPlannerExplanation = false;
        _pendingExplanationPacket = null;
        _pendingExplanationQuote = null;
        _plannerExplanationError =
            'The optional explanation quote is unavailable. No content was sent to the external provider, no credits were charged, and your plan is unchanged.';
      });
    }
  }

  Future<void> _retryPlannerExplanation() async {
    if (_requestingPlannerExplanation) return;
    final PlannerExplanationPacket? packet = _pendingExplanationPacket;
    final PlannerExplanationQuote? quote = _pendingExplanationQuote;
    if (packet == null ||
        quote == null ||
        quote.expiresAt.isBefore(DateTime.now().toUtc()) ||
        !_plannerResponseMatches(packet)) {
      setState(_clearPlannerExplanationState);
      await _requestPlannerExplanation();
      return;
    }
    await _executePlannerExplanation(packet: packet, quote: quote);
  }

  Future<void> _executePlannerExplanation({
    required PlannerExplanationPacket packet,
    required PlannerExplanationQuote quote,
  }) async {
    if (!_plannerResponseMatches(packet)) {
      setState(() {
        _clearPlannerExplanationState();
        _plannerExplanationError =
            'The plan changed before the explanation was requested. Request a new quote for the visible plan.';
      });
      return;
    }
    setState(() {
      _requestingPlannerExplanation = true;
      _plannerExplanationError = null;
    });
    try {
      final PlannerExplanationPort port = await ref.read(
        plannerExplanationPortProvider.future,
      );
      final PlannerExplanationResult result = await port.execute(
        packet: packet,
        quote: quote,
      );
      if (!mounted || !_plannerResponseMatches(packet)) return;
      if (result.status == PlannerExplanationStatus.replayExpired) {
        setState(() {
          _clearPlannerExplanationState();
          _plannerExplanationError =
              'The short replay window ended. Request a new quote to generate another optional explanation.';
        });
        return;
      }
      setState(() {
        _requestingPlannerExplanation = false;
        _pendingExplanationPacket = null;
        _pendingExplanationQuote = null;
        _plannerExplanationResult = result;
        _plannerExplanationError = null;
      });
    } on Object catch (error, stackTrace) {
      Logger.errorCategory(
        'planner_explanation',
        'Optional Planner explanation execution failed.',
        error,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _requestingPlannerExplanation = false;
        _plannerExplanationError =
            'The optional explanation was not generated. Your deterministic plan is unchanged. Retry reuses the same request so it cannot charge twice.';
      });
    }
  }

  bool _plannerResponseMatches(PlannerExplanationPacket packet) {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null || response.isClarification) return false;
    try {
      return PlannerExplanationPacket.fromPlannerResponse(
            response,
          ).responseDigest ==
          packet.responseDigest;
    } on Object {
      return false;
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
    final PlannerRoutineCopy routine = ChronoSparkLocalizations.of(
      context,
    ).plannerRoutine;
    ref.listen(currentPlannerEmotionProvider, (previous, next) {
      if (previous != next) _clearChangedCheckIn();
    });
    ref.listen(
      consentedHumanContextProvider.select((value) => value.emotionAllowed),
      (previous, next) {
        if (previous != next) _clearChangedCheckIn();
      },
    );
    ref.listen(selectedPlanningNoteProvider, (previous, next) {
      if (previous?.asData?.value != next.asData?.value) _clearChangedCheckIn();
    });
    ref.watch(decisionOutcomesProvider);
    ref.watch(learningPausedProvider);
    ref.listen<String>(
      smartPlannerPersonContextBehaviorRevisionForDecisionProvider(
        _plannerPersonContextDecisionText ?? '',
      ),
      (String? previous, String next) {
        _invalidatePlannerOutputForPersonContext(next);
      },
    );
    final AsyncValue<bool> plannerAvailability = ref.watch(
      smartPlannerAvailabilityProvider,
    );
    final bool plannerAvailable = plannerAvailability.asData?.value ?? false;
    final PlannerV2Response? plannerResponse = _plannerResponse;
    final String effectivePlannerMessage =
        plannerResponse?.toAccessibleText() ?? '';
    final String plannerSpokenSummary =
        plannerResponse?.toSpokenSummary() ?? '';
    final bool hasPlannerMessage = plannerResponse != null;
    final bool plannerExplanationAvailable =
        ref.watch(plannerExplanationAvailabilityProvider).asData?.value ==
        PlannerExplanationAvailability.available;
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
                  key: const Key('planner-content-scroll'),
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
                            routine.currentCheckInSection,
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
                            onChanged: (v) {
                              if (_energy == v) return;
                              _clearChangedCheckIn();
                              setState(() => _energy = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          const _PlannerEmotionCheckIn(),
                          const Divider(color: Colors.white12),
                          const SizedBox(height: 8),
                          Text(
                            routine.planningContextSection,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.neonCyan,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            label: routine.planningContextLabel,
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
                              decoration: InputDecoration(
                                hintText: routine.planningContextHint,
                                hintStyle: const TextStyle(
                                  color: Color(0xFFAEB9D0),
                                  fontSize: 16,
                                  height: 1.5,
                                  letterSpacing: 0,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              onChanged: (_) => _clearChangedCheckIn(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            routine.ephemeralNotice,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.45,
                              letterSpacing: 0,
                            ),
                          ),
                          const _SelectedPlanningNoteCard(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PlannerAvailabilityStatus(
                      availability: plannerAvailability,
                      onRetry: () =>
                          ref.invalidate(smartPlannerAvailabilityProvider),
                    ),
                    const SizedBox(height: 10),
                    TemporalActionButton(
                      key: const Key('planner-guidance-button'),
                      label: plannerAvailability.isLoading
                          ? routine.checkingButton
                          : !plannerAvailable
                          ? routine.unavailableButton
                          : _gettingPlanningGuidance
                          ? routine.thinkingButton
                          : routine.guidanceButton(refresh: _saved),
                      accent: AppColors.neonCyan,
                      icon: Icons.auto_awesome_rounded,
                      onPressed:
                          !plannerAvailable ||
                              _gettingPlanningGuidance ||
                              _sendingFollowUp
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
                        label: routine.guidanceReady,
                        child: _PlannerV2ResponsePanel(
                          response: plannerResponse,
                          controlsEnabled:
                              !_gettingPlanningGuidance && !_sendingFollowUp,
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
                      if (_showFirstUseContextOffer &&
                          !plannerResponse.isClarification) ...<Widget>[
                        const SizedBox(height: 12),
                        FirstUseContextOfferCard(
                          immediateGoal:
                              _planningGuidancePrompt ??
                              _notesController.text.trim(),
                          onAdd: () => unawaited(_addFirstUseGoalContext()),
                          onDismiss: () =>
                              setState(() => _showFirstUseContextOffer = false),
                        ),
                      ],
                      if (plannerExplanationAvailable &&
                          !plannerResponse.isClarification) ...[
                        const SizedBox(height: 12),
                        _PlannerExternalExplanationPanel(
                          result: _plannerExplanationResult,
                          error: _plannerExplanationError,
                          requesting: _requestingPlannerExplanation,
                          retryingExistingRequest:
                              _pendingExplanationQuote != null,
                          onRequest: _pendingExplanationQuote == null
                              ? () => unawaited(_requestPlannerExplanation())
                              : () => unawaited(_retryPlannerExplanation()),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _VoiceButton(
                            message: effectivePlannerMessage,
                            languageCode: routine.isSpanish ? 'es' : 'en',
                          ),
                          _VoiceSummaryButton(
                            summary: plannerSpokenSummary,
                            languageCode: routine.isSpanish ? 'es' : 'en',
                          ),
                          const _VoiceAccessibilityButton(),
                          _MicButton(
                            onStart: () => _followUpDictationBase =
                                _followUpController.text.trim(),
                            onRecognized: (String text) {
                              final combined = <String>[
                                if (_followUpDictationBase.isNotEmpty)
                                  _followUpDictationBase,
                                text.trim(),
                              ].join(' ').trim();
                              _followUpController
                                ..text = combined
                                ..selection = TextSelection.collapsed(
                                  offset: combined.length,
                                );
                            },
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
                  onRetry: _retryFollowUp,
                  sending: _sendingFollowUp || _gettingPlanningGuidance,
                  listening: ref.watch(voiceControllerProvider).isListening,
                  errorText: _followUpError,
                ),
              )
            : null,
      ),
    );
  }
}
