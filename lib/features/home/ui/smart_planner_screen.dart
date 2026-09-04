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
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
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
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'smart_planner_screen.widgets.dart';

const String _plannerUnavailableMessage =
    'Smart Planner is not enabled for this account yet. Your check-in was not saved or changed.';
const String _plannerRetryMessage =
    'Guidance could not be generated. Your check-in is still here. Tap GET GUIDANCE to retry.';
const String _plannerPersonContextChangedMessage =
    'Your Person Context changed, so the previous guidance was cleared. Tap GET GUIDANCE to review a current plan.';

@immutable
final class _SmartPlannerConsentCopy {
  const _SmartPlannerConsentCopy({required this.isSpanish});

  factory _SmartPlannerConsentCopy.of(BuildContext context) =>
      _SmartPlannerConsentCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  final bool isSpanish;

  String get priorityTitle => isSpanish
      ? '¿Guardar tu prioridad actual?'
      : 'Save your current priority?';
  String get priorityIntroduction => isSpanish
      ? 'Opcional. Escribe una sola prioridad actual con tus propias palabras. No añadas un perfil de personalidad, una historia de vida ni una etiqueta emocional.'
      : 'Optional. Enter one exact current priority in your own words. Do not add a personality profile, life history, or emotional label.';
  String get priorityLabel =>
      isSpanish ? 'Prioridad actual exacta' : 'Exact current priority';
  String get priorityHint => isSpanish
      ? 'Ejemplo: La preparación para la prueba cerrada es lo primero.'
      : 'Example: Closed-test readiness comes first.';
  String get priorityDisclosure => isSpanish
      ? 'Propósito: apoyo para decisiones\nAlcance: solo Planificador Inteligente\nCaducidad: se elimina automáticamente después de 30 días\nEfecto: puede resolver un empate ajustado mientras esta prioridad esté activa; no se convierte en un dato de identidad.'
      : 'Purpose: decision support\nSurface scope: Smart Planner only\nExpiry: automatically deleted after 30 days\nEffect: may break a close ranking tie while this priority is active; it does not become an identity fact.';
  String get priorityConsent => isSpanish
      ? 'Doy mi consentimiento para guardar solo este texto exacto con el propósito, alcance y caducidad indicados arriba.'
      : 'I consent to saving only this exact text for the purpose, scope, and expiry above.';
  String get useOnlyThisTime =>
      isSpanish ? 'Usar solo esta vez' : 'Use only this time';
  String get saveWithConsent =>
      isSpanish ? 'Guardar con consentimiento' : 'Save with consent';
  String get prioritySaved => isSpanish
      ? 'Contexto opcional guardado con consentimiento · solo Planificador Inteligente · caduca en 30 días · revísalo o elimínalo en Ajustes de contexto.'
      : 'Optional context saved with consent · Smart Planner only · expires in 30 days · review or delete in Context settings.';
  String get preferenceTitle => isSpanish
      ? '¿Recordar una preferencia del Planificador Inteligente?'
      : 'Remember a Smart Planner preference?';
  String get preferenceIntroduction => isSpanish
      ? 'Usar solo esta vez es la opción predeterminada. Escribe únicamente la preferencia exacta sobre el estilo de planificación que quieras guardar; no se copiarán tu registro, emoción ni respuesta.'
      : 'Use only this time is the default. Enter only the exact planning-style preference you want stored; your check-in, emotion, and response are not copied.';
  String get preferenceLabel =>
      isSpanish ? 'Preferencia exacta' : 'Exact preference';
  String get preferenceHint => isSpanish
      ? 'Ejemplo: Prefiere un siguiente paso pequeño antes de ideas opcionales más ambiciosas.'
      : 'Example: Prefer one small next step before optional stretch ideas.';
  String get deleteAfter => isSpanish
      ? 'Eliminar automáticamente después de'
      : 'Automatically delete after';
  String retentionLabel(int days) {
    if (!isSpanish) return days == 365 ? '1 year' : '$days days';
    return days == 365 ? '1 año' : '$days días';
  }

  String receiptPreview(int days) => isSpanish
      ? 'Vista previa del recibo\nMotivo: guardar esta preferencia para tu revisión y uso futuro opcional\nLímite de recuperación: solo guía consentida del Planificador Inteligente\nOrigen: solo Planificador Inteligente\nCaducidad: $days días\nControles: ver, corregir, exportar y eliminar en Ajustes'
      : 'Receipt preview\nWhy: save this preference for your review and future opt-in use\nRecall boundary: consented Smart Planner guidance only\nSource: Smart Planner only\nExpiry: $days days\nControls: view, correct, export, delete in Settings';
  String get preferenceConsent => isSpanish
      ? 'Doy mi consentimiento explícito para guardar esta preferencia exacta.'
      : 'I explicitly consent to storing this exact preference.';
  String get rememberPreference =>
      isSpanish ? 'Recordar preferencia' : 'Remember preference';
  String get usedOnce => isSpanish
      ? 'Se usó solo para este registro. No se guardó memoria duradera.'
      : 'Used only for this check-in. No durable memory was saved.';
  String preferenceSaved(String expiry) => isSpanish
      ? 'Preferencia guardada con consentimiento. Su uso queda limitado a la guía del Planificador Inteligente · caduca $expiry · adminístrala en Ajustes.'
      : 'Preference saved with consent. Recall stays limited to Smart Planner guidance · expires $expiry · manage in Settings.';
  String get contextSaveFailed => isSpanish
      ? 'No se pudo guardar el contexto opcional. Tu texto no se añadió. Inténtalo de nuevo.'
      : 'Optional context could not be saved. Your text was not added. Retry.';
  String get preferenceSaveFailed => isSpanish
      ? 'No se pudo guardar la preferencia. No se creó memoria duradera. Inténtalo de nuevo.'
      : 'The preference could not be saved. No durable memory was created. Retry.';
}

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
  String? _plannerPersonContextBehaviorRevision;
  String? _plannerPersonContextDecisionText;
  OperatingDecisionReceipt? _operatingReceipt;
  String? _shownOperatingReceiptId;
  String? _followUpError;
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

    if (!await _confirmEmotionalSafetyRoute(notes, planner)) {
      return;
    }
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
            supportivePauseReason: supportiveCopy.pauseReason,
            supportiveQuestion: supportiveCopy.question,
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
        supportivePauseReason: supportiveCopy.pauseReason,
        supportiveQuestion: supportiveCopy.question,
      );
      final PlannerV2Response effectiveResponse = _applyReviewableLearning(
        fallback.plannerResponse,
      );
      final bool showContextOffer =
          !effectiveResponse.isClarification &&
          await _claimFirstUseContextOffer();
      if (!mounted) return;
      setState(() {
        _gettingPlanningGuidance = false;
        _planningGuidancePrompt = fallback.prompt;
        _planningGuidanceMessage = fallback.message;
        _plannerResponse = effectiveResponse;
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
    final PlannerV2Response effectiveResponse = _applyReviewableLearning(
      result.plannerResponse,
    );
    final bool showContextOffer =
        !effectiveResponse.isClarification &&
        await _claimFirstUseContextOffer();
    if (!mounted) return;

    setState(() {
      _planningGuidancePrompt = result.prompt;
      _planningGuidanceMessage = result.message;
      _plannerResponse = effectiveResponse;
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
    final TextEditingController controller = TextEditingController();
    bool consent = false;
    final String? exactText = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
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
      ),
    );
    controller.dispose();
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
        code: 'planner.person_context_save_failed',
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

  Future<void> _sendFollowUp() async {
    if (_sendingFollowUp) return;
    final String text = _followUpController.text.trim();
    if (text.isEmpty) return;
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    if (!await _confirmEmotionalSafetyRoute(text, planner)) {
      return;
    }
    final ({String? pauseReason, String? question}) supportiveCopy =
        _localizedSupportiveCopy(text, planner);
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
            supportivePauseReason: supportiveCopy.pauseReason,
            supportiveQuestion: supportiveCopy.question,
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _followUps.add(_Exchange(question: text, answer: result.message));
        _plannerResponse = result.plannerResponse;
        _plannerPersonContextDecisionText = result.prompt;
        _plannerPersonContextBehaviorRevision =
            _personContextBehaviorRevisionFor(result);
        _operatingReceipt = result.operatingReceipt;
        _showWhy = false;
        _showEvidence = false;
        _plannerActionStatus = null;
        _clearPlannerExplanationState();
        _sendingFollowUp = false;
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
      recommendationHelped: true,
    );
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
    setState(() {
      _planningGuidanceMessage = null;
      _planningGuidancePrompt = null;
      _plannerResponse = null;
      _plannerPersonContextDecisionText = null;
      _plannerPersonContextBehaviorRevision = currentRevision;
      _operatingReceipt = null;
      _shownOperatingReceiptId = null;
      _followUps.clear();
      _followUpError = null;
      _plannerActionStatus = null;
      _guidanceError = _plannerPersonContextChangedMessage;
      _saved = false;
      _showFirstUseContextOffer = false;
      _showWhy = false;
      _showEvidence = false;
      _clearPlannerExplanationState();
    });
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
      _clearPlannerExplanationState();
    });
    _recordOperatingOutcome(
      DecisionOutcomeKind.rejected,
      detail:
          'Rejected the current receipt approach by choosing Different approach.',
      optionChosen: next.name,
      optionSizeMinutes: response.optionByKind[next]?.estimatedMinutes,
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
    final TextEditingController preferenceController = TextEditingController();
    int retentionDays = 90;
    bool consentConfirmed = false;
    final _PreferenceMemoryChoice? choice =
        await showDialog<_PreferenceMemoryChoice>(
          context: context,
          builder: (BuildContext dialogContext) => StatefulBuilder(
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
                          DropdownButtonFormField<int>(
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
          ),
        );
    preferenceController.dispose();
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
        code: 'planner.preference_save_failed',
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

  Future<bool> _confirmPlannerExplanationQuote(
    PlannerExplanationQuote quote,
  ) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('External AI explanation'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Your deterministic Planner V2 result remains the authority. This optional service can explain the visible plan but cannot change, save, schedule, or create anything.',
              ),
              const SizedBox(height: 14),
              Text('Provider: ${quote.provider}'),
              Text('Model: ${quote.modelLabel}'),
              Text('Expected cost: ${quote.expectedCredits} AI credits'),
              Text(
                'First-party replay window: ${quote.replayWindowSeconds} seconds',
              ),
              const SizedBox(height: 12),
              const Text(
                'Data sent after confirmation:',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...quote.transmittedDataCategories.map(
                (String category) => Text('• $category'),
              ),
              const SizedBox(height: 12),
              const Text(
                'The quote used this minimized packet only with ChronoSpark\'s first-party function. Nothing has been sent to Anthropic yet.',
              ),
              const SizedBox(height: 12),
              const Text(
                'ChronoSpark keeps response content only for the short replay window, then retains billing metadata. This quote is available only after the first-party service reports the provider-retention and qualified safety-review gates approved. Independent release evidence is still required before this feature can be enabled.',
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('planner-explanation-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('planner-explanation-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Send and spend ${quote.expectedCredits}'),
          ),
        ],
      ),
    );
    return approved ?? false;
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
    final ConsentedHumanContext humanContext = ref.watch(
      consentedHumanContextProvider,
    );
    final AsyncValue<bool> plannerAvailability = ref.watch(
      smartPlannerAvailabilityProvider,
    );
    final bool plannerAvailable = plannerAvailability.asData?.value ?? false;
    final PlannerV2Response? plannerResponse = _plannerResponse;
    final String effectivePlannerMessage =
        plannerResponse?.toAccessibleText() ?? '';
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
                    _PlannerAvailabilityStatus(
                      availability: plannerAvailability,
                      onRetry: () =>
                          ref.invalidate(smartPlannerAvailabilityProvider),
                    ),
                    const SizedBox(height: 10),
                    TemporalActionButton(
                      label: plannerAvailability.isLoading
                          ? 'CHECKING ACCESS...'
                          : !plannerAvailable
                          ? 'PLANNER UNAVAILABLE'
                          : _gettingPlanningGuidance
                          ? 'THINKING...'
                          : (_saved ? 'REFRESH GUIDANCE' : 'GET GUIDANCE'),
                      accent: AppColors.neonCyan,
                      icon: Icons.auto_awesome_rounded,
                      onPressed: !plannerAvailable || _gettingPlanningGuidance
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
