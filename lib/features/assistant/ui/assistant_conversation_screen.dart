import 'dart:async';
import 'dart:convert';

import 'package:fantastic_guacamole/core/network/network_status_service.dart';
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
import 'package:fantastic_guacamole/state/providers/billing_availability_provider.dart';
import 'package:fantastic_guacamole/state/providers/consented_human_context_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/planning_note_provider.dart';
import 'package:fantastic_guacamole/state/providers/route_paths_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

part 'assistant_conversation_screen.consent.dart';
part 'assistant_conversation_screen.copy.dart';
part 'assistant_conversation_screen.history.dart';
part 'assistant_conversation_screen.options.dart';
part 'assistant_conversation_screen.pending.dart';
part 'assistant_conversation_screen.receipt.dart';
part 'assistant_conversation_screen.scope.dart';
part 'assistant_conversation_screen.send.dart';

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
  // The error is about running out of credits: Get credits is offered.
  bool _outOfCredits = false;
  // The latest balance a server answer reported here (see the receipt part).
  int? _reportedBalance;
  // A request since the wallet was loaded may have changed the balance.
  bool _walletUntrusted = false;
  ConversationQuote? _pending;
  // The operation whose confirmed request has started its storage write:
  // from then on it is sent (see _send), so Stop waiting no longer withdraws
  // it.
  int? _committingOperation;
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
  // Chat only: whether [_sources] is the person's own choice, and the
  // one-time explanation of the default (see the scope part).
  bool _sourcesChosen = false;
  bool _scopeExplained = false;
  bool _scopeNoticeVisible = false;
  // The on-device suggestion for the current draft (see the send part).
  bool _freeSuggested = false;
  int _suggestionCheck = 0;
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
    _input.addListener(_onDraftChanged);
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
    _input
      ..removeListener(_onDraftChanged)
      ..dispose();
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
              // Title and content scroll together and the choices stay in
              // view, so a long title at large text cannot push them off.
              return AlertDialog(
                scrollable: true,
                title: Text(title),
                content: SizedBox(width: 520, child: content),
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

  /// Tapping send confirms the price shown on the button. [showPreview]
  /// opens the full preview even when this selection was already previewed.
  Future<void> _send({bool retry = false, bool showPreview = false}) async {
    if (_busy) return;
    if (!retry && _input.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            showPreview
                ? copy(
                    'Type a question first to see exactly what would be sent with it.',
                    'Escribe una pregunta primero para ver exactamente qué se enviaría con ella.',
                  )
                : copy(
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
    // Offline: said before anything is built, previewed, priced or stored.
    // A request already confirmed and stored (retry) follows its recovery.
    if (!retry && _offline) {
      _showFailure(_offlineText);
      return;
    }
    setState(() {
      _busy = true;
      _waitIndicatorDismissed = false;
      _error = null;
      _outOfCredits = false;
      // The one-time line has done its job once a request starts.
      _scopeNoticeVisible = false;
    });
    // Keep the wait indicator and its Stop waiting button in view; the
    // information row above the input leaves less room for the list.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
    bool current() =>
        mounted && generation == _generation && operation == _operation;
    ConversationQuote? executing;
    final registry = ref.read(conversationExecutionRegistryProvider);
    try {
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
        // The full preview opens by itself the first time and whenever the
        // selected information changes; nothing is sent before it is
        // accepted.
        final previews = ref.read(conversationPreviewMemoryProvider);
        final selection = _selectionKey(packet);
        if (showPreview || !previews.hasAccepted(widget.surface, selection)) {
          final proceed = await _reviewWhatIsSent(prompt, packet);
          if (!current() || !proceed) return;
          previews.accept(widget.surface, selection);
        }
        // Tapping send confirmed the price on the button. The signed quote
        // is fetched now; a different price is asked about before charging.
        quote = await service
            .quote(packet)
            .timeout(
              ref.read(conversationRequestTimeoutProvider),
              onTimeout: () => throw const ConversationFailure('quote_timeout'),
            );
        if (!current()) return;
        if (quote.credits != conversationMessageCredits) {
          final accepted = await _confirmChangedPrice(quote.credits);
          if (!current() || !accepted) return;
        }
        // Store the confirmed request before sending it, so its reply can be
        // collected if this screen closes. Without that, send nothing.
        final repository = ref.read(
          assistantConversationHistoryRepositoryProvider,
        );
        final record = PendingConversationRequest(
          quote: quote,
          savedAt: DateTime.now(),
        );
        // Stop waiting decides, inside the storage queue, whether this request
        // is written at all. Until the write starts, Stop waiting (a later
        // operation) withdraws it: nothing is stored, so no path can send it
        // later, whatever happens to the account or sign-in meanwhile. Once
        // the write starts ([_committingOperation]), Stop waiting treats it as
        // confirmed and says so. Leaving the screen without tapping Stop keeps
        // the Phase 1 design: the stored request is collected on return.
        final bool replacedUntold;
        try {
          if (repository == null) throw StateError('chat_account_unavailable');
          replacedUntold = await repository.savePending(
            record,
            commit: () {
              if (operation != _operation) return false;
              _committingOperation = operation;
              return true;
            },
          );
        } on Object {
          // Withdrawn by Stop waiting: its message already says nothing was
          // sent or charged, which is true.
          if (operation != _operation) return;
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
        throw ConversationFailure(
          'response_withheld',
          remainingCredits: answer.remainingCredits,
        );
      }
      // Counted from the packet this reply answered, which for a recovered
      // reply is its own stored request.
      final receipt = ConversationReplyReceipt.fromReply(quote.packet, answer);
      setState(() {
        _history.addAll([
          {'role': 'user', 'content': prompt},
          {
            'role': 'assistant',
            'content': review.publishableText,
            ConversationReplyReceipt.turnKey: receipt.encode(),
          },
        ]);
        _reportedBalance = answer.remainingCredits;
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
      _refreshWalletLater();
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
      _noteFailureBalance(
        error.remainingCredits,
        sentForReply: executing != null,
      );
      final outOfCredits = {
        'insufficient_credits',
        'credits_exhausted',
      }.contains(error.code);
      _showFailure(
        recovered &&
                {'quote_expired', 'credit_quote_required'}.contains(error.code)
            ? _pendingExpiredText(questionRestored: true)
            : outOfCredits
            ? _outOfCreditsText(
                balance: error.remainingCredits,
                needed: executing?.credits ?? conversationMessageCredits,
              )
            : _failureText(error.code, balance: error.remainingCredits),
        outOfCredits: outOfCredits,
      );
      _refreshWalletLater();
    } on Object {
      if (!current()) return;
      if (executing != null) {
        _noteFailureBalance(null, sentForReply: true);
      }
      _showFailure(
        executing == null
            // Nothing was handed on for a reply, so nothing was charged.
            ? copy(
                'The AI service could not be reached. Nothing was sent for a reply and nothing was charged. Your question is retained; tap send to try again.',
                'No se pudo contactar con el servicio de IA. No se envió nada para responder y no se cobró nada. Tu pregunta se conserva; toca enviar para intentarlo de nuevo.',
              )
            // Tapping send confirmed the price; the same request is kept.
            : copy(
                'The AI service did not confirm a reply. Your question and this request are kept. Tap Retry same request to try again without a second charge.',
                'El servicio de IA no confirmó una respuesta. Se conservan tu pregunta y esta solicitud. Toca Reintentar la misma solicitud para intentarlo de nuevo sin un segundo cobro.',
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

  void _showFailure(String message, {bool outOfCredits = false}) {
    setState(() {
      _error = message;
      _outOfCredits = outOfCredits;
    });
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
      // Before the confirmed request starts its storage write, stopping
      // withdraws it for good: it is never stored or sent (see _send).
      if (_pending == null && _committingOperation != _operation) {
        _operation++;
        _busy = false;
        _error = _stoppedBeforeSendingText;
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
          _outOfCredits = false;
          _reportedBalance = null;
          _walletUntrusted = false;
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
              // The balance stays in view beside Free tools. At large text it
              // is at the top of the conversation instead, so this fixed area
              // leaves the conversation its room.
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tooltip(
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
                  if (!_largeText) _balanceLine(),
                ],
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
                  if (_largeText) _balanceLine(),
                  const SizedBox(height: 8),
                  Text(
                    copy(
                      'Say what is on your mind or ask about a plan. Replies use this conversation and information you approve. You can correct an answer. Suggestions do not change saved items.',
                      'Cuenta qué te preocupa o pregunta sobre un plan. Las respuestas usan esta conversación y la información que apruebes. Puedes corregirlas. Las sugerencias no cambian elementos guardados.',
                    ),
                  ),
                  if (!planner && consent && _scopeNoticeVisible)
                    _scopeNotice(),
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
                              if (turn['role'] == 'assistant') ...[
                                AssistantResponseBody(text: turn['content']!),
                                _replyReceipt(
                                  turn,
                                  color: lightForms
                                      ? selectedTheme
                                            .colorScheme
                                            .onSurfaceVariant
                                      : Colors.white70,
                                ),
                              ] else
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
                  if (_error != null &&
                      _outOfCredits &&
                      !_busy &&
                      ref.watch(subscriptionPurchasingEnabledProvider))
                    _getCreditsAction(),
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
            _boundedBottom([
              if (!planner && _historyReady)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _scopeChips(enabled: enabled),
                ),
              if (planner && consent)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _plannerScopeLine(),
                ),
              // A suggestion only: sending stays available either way.
              if (consent && enabled && _freeSuggested) _freeSuggestion(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                              counterStyle: const TextStyle(
                                color: Colors.white70,
                              ),
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
                        if (ref.watch(voiceInputEnabledProvider)) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            color: Colors.cyanAccent,
                            disabledColor: Colors.white38,
                            tooltip: copy(
                              listening
                                  ? 'Stop voice input'
                                  : 'Start voice input',
                              listening
                                  ? 'Detener entrada de voz'
                                  : 'Iniciar entrada de voz',
                            ),
                            onPressed: !enabled && !listening
                                ? null
                                : () async {
                                    if (listening) {
                                      await ref
                                          .read(
                                            voiceControllerProvider.notifier,
                                          )
                                          .stopListening();
                                      return;
                                    }
                                    final VoiceController voiceController = ref
                                        .read(voiceControllerProvider.notifier);
                                    _dictationDraftBase = _input.text;
                                    final int revision =
                                        voiceController.lifecycleRevision;
                                    final int activation = _voiceActivation;
                                    await startVoiceInputWithConsent(
                                      context: context,
                                      onStart: () =>
                                          voiceController.startListening(
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
                              listening
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                            ),
                          ),
                        ],
                        if (consent && _largeText) ...[
                          const SizedBox(width: 4),
                          _previewIconButton(
                            enabled: enabled,
                            listening: listening,
                          ),
                        ],
                        if (!consent) ...[
                          const SizedBox(width: 8),
                          _offSendButton(listening: listening),
                        ],
                      ],
                    ),
                    if (consent)
                      _sendControls(enabled: enabled, listening: listening),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );
    return PopScope(canPop: !_busy, child: scaffold);
  }
}
