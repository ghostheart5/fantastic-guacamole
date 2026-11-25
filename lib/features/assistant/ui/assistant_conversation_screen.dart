import 'dart:async';

import 'package:fantastic_guacamole/domain/entities/assistant_conversation_history.dart';
import 'package:fantastic_guacamole/features/assistant/ui/ai_chat_consent.dart';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_response_body.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/assistant/axiomara_router_contract.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/release/assistant_release_control.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/features/permissions/voice_input_consent.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/ai_content_report_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_history_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_release_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'assistant_conversation_screen.consent.dart';
part 'assistant_conversation_screen.copy.dart';
part 'assistant_conversation_screen.history.dart';
part 'assistant_conversation_screen.options.dart';
part 'assistant_conversation_screen.pending.dart';

/// The conversational route is explicitly model-backed. Local tools remain an
/// intentional user choice, never an invisible fallback for a failed request.
enum _LocalRouteChoice { freeTools, aiPrice }

/// The artwork stays dark in both form modes. Only body text/list chrome gets
/// contrast colors here; fields and dropdown menus keep the selected app theme.
class _ConversationBody extends StatelessWidget {
  const _ConversationBody({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: const TextStyle(color: Colors.white),
    child: ListTileTheme.merge(
      textColor: Colors.white,
      iconColor: Colors.white70,
      child: ExpansionTileTheme(
        data: Theme.of(context).expansionTileTheme.copyWith(
          textColor: Colors.white,
          collapsedTextColor: Colors.white,
          iconColor: Colors.white70,
          collapsedIconColor: Colors.white70,
        ),
        child: SafeArea(child: child),
      ),
    ),
  );
}

class AssistantConversationScreen extends ConsumerStatefulWidget {
  const AssistantConversationScreen({
    super.key,
    required this.surface,
    required this.onLocalTools,
    this.onLocalToolsWithDraft,
    this.isActive = true,
  });
  final ConversationSurface surface;
  final VoidCallback onLocalTools;
  final ValueChanged<String>? onLocalToolsWithDraft;
  final bool isActive;
  @override
  ConsumerState<AssistantConversationScreen> createState() =>
      _AssistantConversationScreenState();
}

class _AssistantConversationScreenState
    extends ConsumerState<AssistantConversationScreen> {
  final _input = TextEditingController();
  final _filter = TextEditingController();
  final _scenario = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _history = [];
  VoiceController? _voiceControllerForDispose;
  bool _busy = false;
  bool _waitIndicatorDismissed = false;
  String? _error;
  ConversationQuote? _pending;
  String? _recoveringRequestId;
  int _generation = 0;
  int _operation = 0;
  Timer? _paidWaitTimer;
  BuildContext? _dialogContext;
  Route<dynamic>? _dialogRoute;
  String _dictationDraftBase = '';
  int _voiceActivation = 0;
  double? _energy;
  String? _attachedTaskId;
  bool _attachedTaskOnly = true;
  SIV2Intent _intent = SIV2Intent.answer;
  SIV2TimeRange _range = SIV2TimeRange.all;
  Set<SIV2Source> _sources = SIV2Source.values.toSet();
  bool _historyLoading = true;
  bool _historyReady = false;
  bool _historySaveFailed = false;
  bool _historyConflict = false;
  bool _historyClearFailed = false;
  int _historyEpoch = 0;
  int _storedHistoryRevision = 0;
  Future<void> _historyWriteTail = Future<void>.value();
  void _updateHistory(VoidCallback update) => setState(update);
  // Lets the part-file extensions rebuild the screen.
  void _rebuild(VoidCallback update) => setState(update);
  bool get _spanish => ChronoSparkLocalizations.of(context).isSpanish;
  String copy(String en, String es) => _spanish ? es : en;

  @override
  void initState() {
    super.initState();
    if (widget.surface == ConversationSurface.si) {
      _sources = <SIV2Source>{};
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadChat());
      });
    }
    if (widget.surface != ConversationSurface.planner) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scope = ref.read(accountStorageScopeProvider).v2Namespace;
      if (scope == null) return;
      final request = ref
          .read(smartPlannerFirstValueProvider.notifier)
          .takeFor(accountScopeId: scope, now: DateTime.now().toUtc());
      if (request == null) return;
      setState(() {
        // Refresh form initial values when the staged request arrives after
        // async route selection, including its optional energy value.
        _generation++;
        _input.text = request.prompt ?? '';
        _energy = request.energy;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadPlannerPending());
    });
  }

  @override
  void didUpdateWidget(covariant AssistantConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _voiceActivation++;
      final controller = _voiceControllerForDispose;
      controller?.invalidatePendingCapture();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller != null) unawaited(controller.stopListening());
      });
    }
  }

  @override
  void dispose() {
    _voiceActivation++;
    _voiceControllerForDispose?.invalidatePendingCapture();
    _paidWaitTimer?.cancel();
    final VoiceController? voiceController = _voiceControllerForDispose;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (voiceController != null) {
          unawaited(voiceController.stopListening());
        }
      } on Object {
        // The provider may have been disposed with an account or app boundary.
      }
    });
    final route = _dialogRoute;
    // Authentication or eligibility can remove this screen while its dialog is
    // on the root navigator. Remove that exact route after the tree is stable.
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = route.navigator;
        if (route.isActive && navigator != null && navigator.mounted) {
          navigator.removeRoute(route, false);
        }
      });
    }
    _input.dispose();
    _filter.dispose();
    _scenario.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirm({
    required String title,
    required Widget content,
    required String action,
  }) async {
    try {
      return await showDialog<bool>(
            context: context,
            builder: (ctx) {
              _dialogContext = ctx;
              _dialogRoute = ModalRoute.of(ctx);
              return AlertDialog(
                title: Text(title),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(child: content),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(copy('Cancel', 'Cancelar')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(action),
                  ),
                ],
              );
            },
          ) ??
          false;
    } finally {
      _dialogContext = null;
      _dialogRoute = null;
    }
  }

  Future<_LocalRouteChoice?> _chooseFreeRoute() async {
    try {
      return await showDialog<_LocalRouteChoice>(
        context: context,
        builder: (ctx) {
          _dialogContext = ctx;
          _dialogRoute = ModalRoute.of(ctx);
          return AlertDialog(
            title: Text(copy('Free on-device option', 'Opción local gratis')),
            content: Text(
              copy(
                'This looks like a question the on-device tools can handle. You can carry your draft there for free, or continue to review the AI credit price. Nothing has been sent or charged.',
                'Parece una pregunta que las herramientas locales pueden atender. Puedes llevar allí tu borrador gratis o continuar para revisar el precio en créditos de IA. No se ha enviado ni cobrado nada.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(copy('Cancel', 'Cancelar')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _LocalRouteChoice.aiPrice),
                child: Text(copy('Review AI price', 'Revisar precio de IA')),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, _LocalRouteChoice.freeTools),
                child: Text(copy('Use free tools', 'Usar herramientas gratis')),
              ),
            ],
          );
        },
      );
    } finally {
      _dialogContext = null;
      _dialogRoute = null;
    }
  }

  Future<void> _send({bool retry = false}) async {
    if (_busy) return;
    if (!retry && _input.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy(
              'Type a question first, then tap send.',
              'Escribe una pregunta primero y luego toca enviar.',
            ),
          ),
        ),
      );
      return;
    }
    _paidWaitTimer?.cancel();
    final generation = _generation;
    final operation = ++_operation;
    final prompt = retry
        ? _pending?.packet.toJson()['prompt'] as String?
        : _input.text.trim();
    if (prompt == null) return;
    final safety = EmotionalSafetyPolicy.assess(
      [
        ..._history.where((t) => t['role'] == 'user').map((t) => t['content']),
        prompt,
      ].join(' '),
    );
    if (safety.route != EmotionalSafetyRoute.routine) {
      if (safety.requiresSupportivePause) {
        await showSupportiveDistressDialog(context);
      } else {
        await showCrisisDialog(context);
      }
      return;
    }
    setState(() {
      _busy = true;
      _waitIndicatorDismissed = false;
      _error = null;
    });
    bool current() =>
        mounted && generation == _generation && operation == _operation;
    ConversationQuote? executing;
    final registry = ref.read(conversationExecutionRegistryProvider);
    try {
      if (!retry) {
        final scope = ref.read(accountStorageScopeProvider).v2Namespace;
        final authGeneration = ref.read(authSessionBoundaryProvider).generation;
        if (scope == null) {
          throw const ConversationFailure('authentication_required');
        }
        final decision = await ref
            .read(axiomaraRouterProvider)
            .route(
              accountScopeId: scope,
              input: prompt,
              externalAiAllowed: ref
                  .read(personalizationProfileProvider)
                  .externalAiAllowed,
            );
        if (!current() ||
            ref.read(accountStorageScopeProvider).v2Namespace != scope ||
            ref.read(authSessionBoundaryProvider).generation !=
                authGeneration) {
          return;
        }
        if (decision.route == AxiomaraRoute.local ||
            decision.route == AxiomaraRoute.si) {
          final choice = await _chooseFreeRoute();
          if (!current() ||
              ref.read(accountStorageScopeProvider).v2Namespace != scope ||
              ref.read(authSessionBoundaryProvider).generation !=
                  authGeneration) {
            return;
          }
          if (choice == null) return;
          if (choice == _LocalRouteChoice.freeTools) {
            final handoff = widget.onLocalToolsWithDraft;
            if (handoff == null) {
              widget.onLocalTools();
            } else {
              handoff(prompt);
            }
            return;
          }
        }
      }
      final service = ref.read(conversationServiceProvider);
      var quote = retry ? _pending : null;
      if (quote == null) {
        final packet = await ref
            .read(conversationPacketFactoryProvider)
            .build(
              surface: widget.surface,
              prompt: prompt,
              history: List.of(_history),
              languageCode: _spanish ? 'es' : 'en',
              intent: _intent,
              sources: _sources,
              range: _range,
              entityFilter: _filter.text.trim(),
              scenario: _scenario.text.trim(),
              reportedEnergy: _energy,
              selectedTaskId: _attachedTaskId,
              attachedTaskOnly: _attachedTaskOnly,
            );
        if (!current()) return;
        final attachedNoteSafety = EmotionalSafetyPolicy.assess(
          packet.attachedNoteSafetyText,
        );
        if (attachedNoteSafety.route != EmotionalSafetyRoute.routine) {
          if (!mounted) return;
          if (attachedNoteSafety.requiresSupportivePause) {
            await showSupportiveDistressDialog(context);
          } else {
            await showCrisisDialog(context);
          }
          return;
        }
        final proceed = await _confirm(
          title: copy(
            'Review what AI will receive',
            'Revisa lo que recibirá la IA',
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy(
                  'Your question, up to six recent messages, and the app context below go to Axiomara for a credit quote. If you confirm the price, they go to Anthropic for a response. Anthropic normally retains API content for up to 30 days. This does not save or change your tasks.',
                  'Tu pregunta, hasta seis mensajes recientes y el contexto de abajo se envían a Axiomara para cotizar créditos. Si confirmas el precio, se envían a Anthropic para responder. Anthropic normalmente conserva el contenido de la API hasta 30 días. Esto no guarda ni modifica tus tareas.',
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(prompt),
              ExpansionTile(
                title: Text(copy('Included app context', 'Contexto incluido')),
                children: [SelectableText(_contextPreview(packet))],
              ),
            ],
          ),
          action: copy('Get credit price', 'Consultar precio'),
        );
        if (!current() || !proceed) return;
        quote = await service
            .quote(packet)
            .timeout(
              ref.read(conversationRequestTimeoutProvider),
              onTimeout: () => throw const ConversationFailure('quote_timeout'),
            );
        if (!current()) return;
        final accepted = await _confirm(
          title: copy('Confirm AI request', 'Confirmar solicitud de IA'),
          content: Text(
            copy(
              'This reply costs ${quote.credits} credits. Nothing will be scheduled or marked complete. Send this request?',
              'Esta respuesta cuesta ${quote.credits} créditos. No se programará ni se marcará nada como completado. ¿Enviar esta solicitud?',
            ),
          ),
          action: copy(
            'Use ${quote.credits} credits',
            'Usar ${quote.credits} créditos',
          ),
        );
        if (!current() || !accepted) return;
        // Store the confirmed request before sending it, so its reply can be
        // collected if this screen closes. Without that, send nothing.
        final repository = ref.read(
          assistantConversationHistoryRepositoryProvider,
        );
        final record = PendingConversationRequest(
          quote: quote,
          savedAt: DateTime.now(),
        );
        final bool replacedUntold;
        try {
          if (repository == null) throw StateError('chat_account_unavailable');
          replacedUntold = await repository.savePending(record);
        } on Object {
          throw const ConversationFailure('request_not_saved');
        }
        // Its content is removed once it can no longer be collected, even if
        // no screen is open then.
        registry.schedulePurge(record.collectBefore);
        if (!mounted || !current()) return;
        if (replacedUntold) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_pendingExpiredText(questionRestored: false)),
            ),
          );
        }
        _pending = quote;
      }
      _paidWaitTimer = Timer(ref.read(conversationPaidWaitTimeoutProvider), () {
        if (!current() || !_busy) return;
        setState(() {
          _busy = false;
          _waitIndicatorDismissed = false;
          _error = _failureText('request_timeout');
        });
      });
      executing = quote;
      // Joins a run that outlived an earlier screen instead of sending again.
      final answer = await registry.execute(quote, service);
      if (!current()) return;
      registry.finish(quote.packet.requestId, shown: true);
      final review = const AssistantSafetyPipeline().evaluate(
        AssistantSafetyReview(
          requestId: answer.requestId,
          accountScopeId: quote.packet.accountScope,
          surface: widget.surface == ConversationSurface.planner
              ? AssistantSafetySurface.smartPlanner
              : AssistantSafetySurface.siConsole,
          responseText: answer.text,
          evidenceIds: [
            'conversation:${quote.packet.requestId}',
            ..._recordEvidenceIds(quote.packet),
          ],
          untrustedData: [quote.packet.preview],
          authority: AssistantActionAuthority.readOnly,
          risk: AssistantSafetyRisk.complex,
        ),
      );
      if (!review.mayPublish) {
        throw const ConversationFailure('response_withheld');
      }
      setState(() {
        _history.addAll([
          {'role': 'user', 'content': prompt},
          {'role': 'assistant', 'content': review.publishableText},
        ]);
        if (widget.surface == ConversationSurface.si &&
            _history.length > AssistantConversationHistory.maxMessages) {
          _history.removeRange(
            0,
            _history.length - AssistantConversationHistory.maxMessages,
          );
        }
        _input.clear();
        _pending = null;
        _error = null;
      });
      _persistChat(completedRequestId: quote.packet.requestId);
      ref.invalidate(aiCreditWalletProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          unawaited(
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            ),
          );
        }
      });
    } on ConversationFailure catch (error) {
      if (!current()) return;
      if (<String>{
        'daily_budget_exceeded',
        'timing_context_missing',
        'insufficient_credits',
        'credits_exhausted',
        'request_completed',
        'request_refunded',
        'quote_expired',
        'credit_quote_required',
        'response_withheld',
        'unsafe_upstream_response',
        'inconsistent_upstream_response',
        'upstream_ai_error',
        'truncated_upstream_response',
        'invalid_upstream_response',
        'empty_upstream_response',
      }.contains(error.code)) {
        _pending = null;
        // A terminal answer ends the stored request; it is never re-sent.
        if (executing != null) {
          registry.finish(executing.packet.requestId, shown: true);
          _forgetPending(executing.packet.requestId);
        }
      }
      final recovered =
          executing != null &&
          executing.packet.requestId == _recoveringRequestId;
      _showFailure(
        recovered &&
                {'quote_expired', 'credit_quote_required'}.contains(error.code)
            ? _pendingExpiredText(questionRestored: true)
            : _failureText(error.code),
      );
      ref.invalidate(aiCreditWalletProvider);
    } on Object {
      if (!current()) return;
      _showFailure(
        copy(
          'The AI service did not confirm a reply. Your question is retained. If you already confirmed payment, retry the same request to avoid a second charge.',
          'El servicio de IA no confirmó una respuesta. Tu pregunta se conserva. Si ya confirmaste el pago, reintenta la misma solicitud para evitar otro cobro.',
        ),
      );
    } finally {
      _paidWaitTimer?.cancel();
      _paidWaitTimer = null;
      if (current()) {
        setState(() {
          _busy = false;
          _waitIndicatorDismissed = false;
          _recoveringRequestId = null;
        });
      }
    }
  }

  void _showFailure(String message) {
    setState(() => _error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _stopWaiting() {
    if (!_busy) return;
    setState(() {
      if (_pending == null) {
        _operation++;
        _busy = false;
        _error = copy(
          'Stopped waiting before a paid request was confirmed. Your question is retained.',
          'Se detuvo la espera antes de confirmar una solicitud de pago. Tu pregunta se conserva.',
        );
        return;
      }
      _waitIndicatorDismissed = true;
      _error = copy(
        'The paid request is still finishing safely. Its confirmed reply will appear here when it arrives. If you leave, come back to this screen within a few minutes to collect it without another charge.',
        'La solicitud pagada sigue finalizando de forma segura. La respuesta confirmada aparecerá aquí cuando llegue. Si sales, vuelve a esta pantalla en unos minutos para recibirla sin otro cobro.',
      );
    });
  }

  Future<void> _report(String response) async {
    final generation = _generation;
    var reason = AiContentReportReason.inaccurate;
    final accepted = await _confirm(
      title: copy('Report response', 'Reportar respuesta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            copy(
              'Send this selected response and your reason to Axiomara for review. It may contain details from your planning or conversation. The report is linked to your account and stored for review; the rest of your conversation is not attached.',
              'Envía esta respuesta y el motivo a Axiomara para su revisión. Puede incluir detalles de tus planes o conversación. El informe se vincula a tu cuenta y se guarda para revisión; no se adjunta el resto de la conversación.',
            ),
          ),
          DropdownButtonFormField<AiContentReportReason>(
            initialValue: reason,
            isExpanded: true,
            items: AiContentReportReason.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(switch (value) {
                      AiContentReportReason.unsafe => copy(
                        'Unsafe or harmful',
                        'Insegura o dañina',
                      ),
                      AiContentReportReason.inaccurate => copy(
                        'Inaccurate',
                        'Inexacta',
                      ),
                      AiContentReportReason.privacy => copy(
                        'Privacy concern',
                        'Problema de privacidad',
                      ),
                      AiContentReportReason.other => copy('Other', 'Otro'),
                    }),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) reason = value;
            },
          ),
        ],
      ),
      action: copy('Send report', 'Enviar informe'),
    );
    if (!mounted || generation != _generation || !accepted) return;
    try {
      await ref
          .read(aiContentReportActionsProvider)
          .submit(responseText: response, reason: reason);
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy(
              'Response reported for review.',
              'Respuesta enviada para revisión.',
            ),
          ),
        ),
      );
    } on Object {
      if (!mounted || generation != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy(
              'Could not send the report. Please try again.',
              'No se pudo enviar el informe. Inténtalo de nuevo.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountStorageScopeProvider, (previous, next) {
      if (previous?.v2Namespace != next.v2Namespace) {
        final dialog = _dialogContext;
        if (dialog != null && dialog.mounted) Navigator.pop(dialog);
        unawaited(ref.read(voiceControllerProvider.notifier).stopListening());
        setState(() {
          _generation++;
          _history.clear();
          _pending = null;
          _input.clear();
          _dictationDraftBase = '';
          _filter.clear();
          _scenario.clear();
          _attachedTaskId = null;
          _attachedTaskOnly = true;
          _energy = null;
          _intent = SIV2Intent.answer;
          _range = SIV2TimeRange.all;
          _sources = SIV2Source.values.toSet();
          _busy = false;
          _waitIndicatorDismissed = false;
          _error = null;
          _recoveringRequestId = null;
        });
        _restartChat();
        unawaited(_loadPlannerPending());
      }
    });
    ref.listen(authSessionBoundaryProvider, (previous, next) {
      if (previous != null && previous.generation != next.generation) {
        _restartChat();
        unawaited(_loadPlannerPending());
      }
    });
    final consent = ref.watch(personalizationProfileProvider).externalAiAllowed;
    final VoiceState voice = ref.watch(voiceControllerProvider);
    _voiceControllerForDispose = ref.read(voiceControllerProvider.notifier);
    final bool listening = voice.isListening;
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      if (!widget.isActive) return;
      if (next.error != null &&
          next.error != previous?.error &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              copy(
                'Voice input is unavailable. Check microphone permission and try again.',
                'La entrada de voz no está disponible. Revisa el permiso del micrófono e inténtalo de nuevo.',
              ),
            ),
          ),
        );
      }
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if ((next.isListening || stoppedListening) &&
          next.recognizedText.trim().isNotEmpty) {
        final String transcript = next.recognizedText.trim();
        final String combined = <String>[
          if (_dictationDraftBase.trim().isNotEmpty) _dictationDraftBase.trim(),
          transcript,
        ].join(' ').trim();
        _input
          ..text = combined
          ..selection = TextSelection.collapsed(offset: combined.length);
      }
      if (stoppedListening) {
        _dictationDraftBase = '';
        ref.read(voiceControllerProvider.notifier).clearRecognizedText();
      }
    });
    final planner = widget.surface == ConversationSurface.planner;
    final selectedTheme = Theme.of(context);
    final lightForms = selectedTheme.brightness == Brightness.light;
    final tasks = planner
        ? ref.watch(siV2EvidenceSnapshotProvider).asData?.value.tasks
        : null;
    final enabled =
        widget.isActive &&
        consent &&
        !_busy &&
        _pending == null &&
        (planner || (_historyReady && !_historyLoading && !_historyConflict));
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF07111C),
      appBar: AppBar(
        title: Text(
          planner
              ? copy('Choose a step', 'Elegir un paso')
              : copy('Chat', 'Chat'),
        ),
        leading: BackButton(
          onPressed: _busy
              ? null
              : () => goToAppView(context, ref, AppView.nexus),
        ),
      ),
      body: _ConversationBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: copy('On-device tools', 'Herramientas locales'),
                  child: OutlinedButton.icon(
                    key: const Key('conversation-free-tools'),
                    onPressed: _busy
                        ? null
                        : () {
                            final handoff = widget.onLocalToolsWithDraft;
                            if (handoff == null) {
                              widget.onLocalTools();
                            } else {
                              handoff(_input.text.trim());
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF10203F),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      side: const BorderSide(color: Colors.cyanAccent),
                    ),
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: Text(copy('Free tools', 'Herramientas gratis')),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  // First in the list so it is the first thing seen on open,
                  // but it scrolls, so large text cannot overflow the screen.
                  if (!consent) ...[
                    _aiChatOffNotice(),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    copy(
                      'AI conversation · uses credits',
                      'Conversación con IA · usa créditos',
                    ),
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy(
                      'Say what is on your mind or ask about a plan. Replies use this conversation and information you approve. You can correct an answer. Suggestions do not change saved items.',
                      'Cuenta qué te preocupa o pregunta sobre un plan. Las respuestas usan esta conversación y la información que apruebes. Puedes corregirlas. Las sugerencias no cambian elementos guardados.',
                    ),
                  ),
                  if (!planner) _chatHistoryControls(),
                  ..._conversationOptions(
                    planner: planner,
                    enabled: enabled,
                    tasks: tasks,
                  ),
                  ..._history.map(
                    (turn) => Card(
                      color: lightForms
                          ? (turn['role'] == 'user'
                                ? selectedTheme
                                      .colorScheme
                                      .surfaceContainerHighest
                                : selectedTheme.colorScheme.surface)
                          : turn['role'] == 'user'
                          ? const Color(0xFF162C40)
                          : const Color(0xFF101E2C),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: selectedTheme.colorScheme.onSurface,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                turn['role'] == 'user'
                                    ? copy('You', 'Tú')
                                    : copy('AI response', 'Respuesta de IA'),
                                style: TextStyle(
                                  color: lightForms
                                      ? selectedTheme.colorScheme.primary
                                      : Colors.cyanAccent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (turn['role'] == 'assistant')
                                AssistantResponseBody(text: turn['content']!)
                              else
                                SelectableText(turn['content']!),
                              if (turn['role'] == 'assistant')
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _report(turn['content']!),
                                  icon: const Icon(Icons.flag_outlined),
                                  label: Text(
                                    copy(
                                      'Report response',
                                      'Reportar respuesta',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_busy && !_waitIndicatorDismissed)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const SizedBox.square(
                                dimension: 36,
                                child: CircularProgressIndicator(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  copy(
                                    'Preparing your response…',
                                    'Preparando tu respuesta…',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              key: const Key('conversation-stop-waiting'),
                              onPressed: _stopWaiting,
                              child: Text(
                                copy('Stop waiting', 'Dejar de esperar'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      key: const Key('conversation-error'),
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  if (_pending != null && !_busy)
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton(
                          onPressed: () => _send(retry: true),
                          child: Text(
                            copy(
                              'Retry same request',
                              'Reintentar la misma solicitud',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final confirmed = await _confirm(
                              title: copy(
                                'Start another request?',
                                '¿Iniciar otra solicitud?',
                              ),
                              content: Text(
                                copy(
                                  'The previous request may have used credits. Starting again creates a new priced request. Its reply will not be recovered.',
                                  'La solicitud anterior puede haber usado créditos. Volver a empezar crea una nueva solicitud con precio. No se recuperará su respuesta.',
                                ),
                              ),
                              action: copy(
                                'Start new request',
                                'Iniciar otra solicitud',
                              ),
                            );
                            final abandoned = _pending?.packet.requestId;
                            if (mounted && confirmed && abandoned != null) {
                              setState(() => _pending = null);
                              _forgetPending(abandoned);
                            }
                          },
                          child: Text(
                            copy(
                              'Start another request',
                              'Iniciar otra solicitud',
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('conversation-input'),
                      controller: _input,
                      enabled: enabled,
                      readOnly: listening,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        counterStyle: const TextStyle(color: Colors.white70),
                        labelText: consent
                            ? copy(
                                'Your question or follow-up',
                                'Tu pregunta o continuación',
                              )
                            : copy(
                                'Turn on AI chat to type',
                                'Activa el chat con IA para escribir',
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ref.watch(voiceInputEnabledProvider)) ...[
                    IconButton(
                      color: Colors.cyanAccent,
                      disabledColor: Colors.white38,
                      tooltip: copy(
                        listening ? 'Stop voice input' : 'Start voice input',
                        listening
                            ? 'Detener entrada de voz'
                            : 'Iniciar entrada de voz',
                      ),
                      onPressed: !enabled && !listening
                          ? null
                          : () async {
                              if (listening) {
                                await ref
                                    .read(voiceControllerProvider.notifier)
                                    .stopListening();
                                return;
                              }
                              final VoiceController voiceController = ref.read(
                                voiceControllerProvider.notifier,
                              );
                              _dictationDraftBase = _input.text;
                              final int revision =
                                  voiceController.lifecycleRevision;
                              final int activation = _voiceActivation;
                              await startVoiceInputWithConsent(
                                context: context,
                                onStart: () => voiceController.startListening(
                                  localeId: Localizations.localeOf(
                                    context,
                                  ).toLanguageTag(),
                                ),
                                consentStore: ref.read(
                                  voiceInputConsentStoreProvider,
                                ),
                                isCurrentRequest: () =>
                                    mounted &&
                                    widget.isActive &&
                                    activation == _voiceActivation &&
                                    voiceController.lifecycleRevision ==
                                        revision,
                              );
                            },
                      icon: Icon(
                        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    color: consent ? Colors.cyanAccent : Colors.white38,
                    disabledColor: Colors.white38,
                    tooltip: copy('Send to AI', 'Enviar a IA'),
                    // With AI chat off, the button stays tappable and offers
                    // the consent sheet rather than silently doing nothing.
                    onPressed: listening
                        ? null
                        : enabled
                        ? () => _send()
                        : !consent && widget.isActive && !_busy
                        ? _turnOnAiChat
                        : null,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return PopScope(canPop: !_busy, child: scaffold);
  }
}
