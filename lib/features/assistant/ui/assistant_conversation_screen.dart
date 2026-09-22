import 'dart:async';
import 'package:fantastic_guacamole/features/assistant/ui/assistant_response_body.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/policies/assistant_safety_policy.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/features/permissions/voice_input_consent.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/ai_content_report_provider.dart';
import 'package:fantastic_guacamole/state/providers/assistant_conversation_provider.dart';
import 'package:fantastic_guacamole/state/providers/paywall_provider.dart';
import 'package:fantastic_guacamole/state/providers/personalization_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/state/providers/smart_planner_first_value_provider.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The conversational route is explicitly model-backed. Local tools remain an
/// intentional user choice, never an invisible fallback for a failed request.
class AssistantConversationScreen extends ConsumerStatefulWidget {
  const AssistantConversationScreen({
    super.key,
    required this.surface,
    required this.onLocalTools,
  });
  final ConversationSurface surface;
  final VoidCallback onLocalTools;
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
  late final VoiceController _voiceController;
  bool _busy = false;
  bool _waitIndicatorDismissed = false;
  String? _error;
  ConversationQuote? _pending;
  int _generation = 0;
  int _operation = 0;
  BuildContext? _dialogContext;
  String _dictationDraftBase = '';
  double? _energy;
  String? _attachedTaskId;
  bool _attachedTaskOnly = true;
  SIV2Intent _intent = SIV2Intent.answer;
  SIV2TimeRange _range = SIV2TimeRange.all;
  Set<SIV2Source> _sources = SIV2Source.values.toSet();
  bool get _spanish => ChronoSparkLocalizations.of(context).isSpanish;
  String copy(String en, String es) => _spanish ? es : en;

  @override
  void initState() {
    super.initState();
    _voiceController = ref.read(voiceControllerProvider.notifier);
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
        _input.text = request.prompt ?? '';
        _energy = request.energy;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        unawaited(_voiceController.stopListening());
      } on Object {
        // The provider may have been disposed with an account or app boundary.
      }
    });
    final dialog = _dialogContext;
    final route = dialog != null && dialog.mounted
        ? ModalRoute.of(dialog)
        : null;
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
    }
  }

  Future<void> _send({bool retry = false}) async {
    if (_busy || (!retry && _input.text.trim().isEmpty)) return;
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
              onTimeout: () =>
                  throw const ConversationFailure('request_timeout'),
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
        _pending = quote;
      }
      final answer = await service
          .execute(quote)
          .timeout(
            ref.read(conversationRequestTimeoutProvider),
            onTimeout: () => throw const ConversationFailure('request_timeout'),
          );
      if (!current()) return;
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
        _input.clear();
        _pending = null;
        _error = null;
      });
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
      _showFailure(_failureText(error.code));
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
      if (current()) {
        setState(() {
          _busy = false;
          _waitIndicatorDismissed = false;
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
        'The paid request is still finishing safely. Stay on this screen; its confirmed reply will appear when ready, without another charge.',
        'La solicitud pagada sigue finalizando de forma segura. Permanece en esta pantalla; la respuesta confirmada aparecerá cuando esté lista, sin otro cobro.',
      );
    });
  }

  String _failureText(String code) => switch (code) {
    'insufficient_credits' || 'credits_exhausted' => copy(
      'You do not have enough AI credits. No model answer was generated.',
      'No tienes suficientes créditos de IA. No se generó una respuesta del modelo.',
    ),
    'request_completed' => copy(
      'The server already completed this request, but its reply is unavailable. It did not charge again. Check your credit balance before starting another request.',
      'El servidor ya completó esta solicitud, pero la respuesta no está disponible. No se cobró otra vez. Revisa el saldo antes de iniciar otra solicitud.',
    ),
    'quote_expired' || 'credit_quote_required' => copy(
      'The price expired. Start a new request to review a new quote.',
      'El precio caducó. Inicia otra solicitud para revisar una nueva cotización.',
    ),
    'request_timeout' => copy(
      'The AI service took too long to confirm a reply. Your question and the same priced request are retained. Retry the same request to avoid a second charge.',
      'El servicio de IA tardó demasiado en confirmar una respuesta. Se conservan tu pregunta y la misma solicitud con precio. Reintenta la misma solicitud para evitar un segundo cobro.',
    ),
    'daily_budget_exceeded' => copy(
      'You reached the rolling daily AI safety limit. No credits were charged. Your question and priced request are retained; retry after the limit resets.',
      'Alcanzaste el límite diario móvil de seguridad de IA. No se cobraron créditos. Se conservan tu pregunta y la solicitud con precio; reintenta cuando se restablezca el límite.',
    ),
    'provider_cost_budget_exceeded' => copy(
      'AI requests are temporarily paused by the service spending limit. No credits were charged. Your question and priced request are retained for a later retry.',
      'Las solicitudes de IA están pausadas temporalmente por el límite de gasto del servicio. No se cobraron créditos. Se conservan tu pregunta y la solicitud con precio para reintentarlo más tarde.',
    ),
    'rate_limit_exceeded' => copy(
      'Too many AI requests arrived at once. No credits were charged. Your question is retained; wait a moment and try again.',
      'Llegaron demasiadas solicitudes de IA al mismo tiempo. No se cobraron créditos. Tu pregunta se conserva; espera un momento e inténtalo de nuevo.',
    ),
    'request_denied' => copy(
      'This AI request was denied before processing. No credits were charged. Your question is retained; start a new request or retry after the account limit changes.',
      'Esta solicitud de IA fue rechazada antes de procesarse. No se cobraron créditos. Tu pregunta se conserva; inicia una solicitud nueva o reintenta cuando cambie el límite de la cuenta.',
    ),
    'authorization_changed' => copy(
      'Your account or AI consent changed. This request was stopped.',
      'Cambió tu cuenta o consentimiento de IA. Se detuvo esta solicitud.',
    ),
    'response_withheld' || 'unsafe_upstream_response' => copy(
      'The reply did not pass the response check. It has not been replaced with a stock answer. Check your credit balance before another request.',
      'La respuesta no superó la comprobación. No se sustituyó por una respuesta prefabricada. Revisa el saldo antes de otra solicitud.',
    ),
    _ => copy(
      'The AI service could not complete this request. Your question is retained. You can try again.',
      'El servicio de IA no pudo completar esta solicitud. Tu pregunta se conserva. Puedes intentarlo de nuevo.',
    ),
  };

  Iterable<String> _recordEvidenceIds(ConversationPacket packet) sync* {
    final data = packet.toJson()['context'] as Map;
    for (final source in ['tasks', 'goals', 'milestones']) {
      for (final record
          in (data[source] as List? ?? const [])
              .whereType<Map<Object?, Object?>>()) {
        if (record['id'] case final String id) yield '$source:$id';
      }
    }
    if (data['selectedNoteId'] case final String id) yield 'notes:$id';
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

  String _contextPreview(ConversationPacket packet) {
    final data = Map<String, dynamic>.from(packet.toJson()['context'] as Map);
    final lines = <String>[
      if (data['contextScope'] == 'attachedTaskOnly')
        copy(
          'Context: attached task only. Other records and emotional state are excluded.',
          'Contexto: solo la tarea adjunta. Se excluyen otros registros y el estado emocional.',
        ),
      copy(
        'Selected analysis: ${_intentLabel(_intent)}',
        'Análisis seleccionado: ${_intentLabel(_intent)}',
      ),
      copy(
        'Sources: ${_sources.map(_sourceLabel).join(', ')}',
        'Fuentes: ${_sources.map(_sourceLabel).join(', ')}',
      ),
      copy('Dates: ${_rangeLabel(_range)}', 'Fechas: ${_rangeLabel(_range)}'),
      if (_filter.text.trim().isNotEmpty)
        copy(
          'Title filter: ${_filter.text.trim()}',
          'Filtro de título: ${_filter.text.trim()}',
        ),
      if (_scenario.text.trim().isNotEmpty)
        copy(
          'Hypothetical: ${_scenario.text.trim()}',
          'Hipótesis: ${_scenario.text.trim()}',
        ),
    ];
    final labels = <String, String>{
      'title': copy('Title', 'Título'),
      'description': copy('Details', 'Detalles'),
      'priority': copy('Priority', 'Prioridad'),
      'scheduledStart': copy('Scheduled start', 'Inicio programado'),
      'deadline': copy('Deadline', 'Vencimiento'),
      'targetDate': copy('Target date', 'Fecha objetivo'),
      'estimatedDurationMinutes': copy(
        'Estimated minutes',
        'Minutos estimados',
      ),
      'completionPercent': copy('Recorded progress', 'Progreso registrado'),
      'timestamp': copy('Recorded time', 'Hora registrada'),
      'status': copy('Status', 'Estado'),
      'body': copy('Note', 'Nota'),
    };
    void record(Map<Object?, Object?> values) {
      for (final entry in labels.entries) {
        final value = values[entry.key];
        if (value != null && value.toString().isNotEmpty) {
          lines.add('${entry.value}: $value');
        }
      }
      lines.add('');
    }

    for (final source in SIV2Source.values) {
      final records = data[source.name];
      if (records is! List || records.isEmpty) continue;
      lines.add('\n${_sourceLabel(source)}');
      for (final item in records.whereType<Map<Object?, Object?>>()) {
        record(item);
      }
    }
    if (data['explicitlyAttachedNote'] case final Map<Object?, Object?> note) {
      lines.add(copy('Attached note', 'Nota adjunta'));
      record(note);
    }
    if (data['reportedEnergy'] case final num energy) {
      lines.add(
        copy(
          'Your energy: ${(energy * 100).round()}%',
          'Tu energía: ${(energy * 100).round()}%',
        ),
      );
    }
    if (data['reportedEmotion'] case final String emotion) {
      lines.add(
        copy(
          'Your selected emotional state: $emotion',
          'Tu estado emocional seleccionado: $emotion',
        ),
      );
    }
    final omitted = data['omittedRecordCount'];
    if (omitted is int && omitted > 0) {
      lines.add(
        copy(
          '$omitted additional records are not included.',
          'No se incluyen $omitted registros adicionales.',
        ),
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(accountStorageScopeProvider, (previous, next) {
      if (previous?.v2Namespace != next.v2Namespace) {
        final dialog = _dialogContext;
        if (dialog != null && dialog.mounted) Navigator.pop(dialog, false);
        unawaited(_voiceController.stopListening());
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
        });
      }
    });
    final consent = ref.watch(personalizationProfileProvider).externalAiAllowed;
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
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
        _voiceController.clearRecognizedText();
      }
    });
    final planner = widget.surface == ConversationSurface.planner;
    final tasks = planner
        ? ref.watch(siV2EvidenceSnapshotProvider).asData?.value.tasks
        : null;
    final enabled = consent && !_busy && _pending == null;
    final scaffold = Scaffold(
      backgroundColor: const Color(0xFF07111C),
      appBar: AppBar(
        title: Text(planner ? 'Smart Planner' : 'SI Console'),
        leading: BackButton(
          onPressed: _busy
              ? null
              : () => goToAppView(context, ref, AppView.nexus),
        ),
        actions: [
          IconButton(
            tooltip: copy('On-device tools', 'Herramientas locales'),
            onPressed: _busy ? null : widget.onLocalTools,
            icon: const Icon(Icons.offline_bolt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
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
                      'Ask a question, correct the answer, or add a constraint. Replies use the conversation and the app context you approve. Suggestions do not change saved records.',
                      'Haz una pregunta, corrige la respuesta o añade una restricción. Las respuestas usan la conversación y el contexto que apruebes. Las sugerencias no modifican registros.',
                    ),
                  ),
                  if (!consent) ...[
                    const SizedBox(height: 12),
                    Text(
                      copy(
                        'Enable external AI in Personalization settings to use this conversation.',
                        'Activa la IA externa en Personalización para usar esta conversación.',
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          goToAppView(context, ref, AppView.settings),
                      child: Text(copy('Open settings', 'Abrir ajustes')),
                    ),
                  ],
                  if (planner && tasks != null)
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'conversation-task-${_attachedTaskId ?? 'none'}',
                      ),
                      initialValue: tasks.any((t) => t.id == _attachedTaskId)
                          ? _attachedTaskId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: copy('Attach a task', 'Adjuntar una tarea'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(
                            copy('No specific task', 'Sin tarea específica'),
                          ),
                        ),
                        ...tasks.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: enabled
                          ? (value) => setState(() {
                              _attachedTaskId = value == '' ? null : value;
                              _attachedTaskOnly = true;
                              _history.clear();
                              _pending = null;
                            })
                          : null,
                    ),
                  if (planner && _attachedTaskId != null)
                    SwitchListTile(
                      key: const Key('conversation-task-only'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        copy('Only attached task', 'Solo la tarea adjunta'),
                      ),
                      subtitle: Text(
                        copy(
                          'Turn off to review broader app context. Changing this starts a new conversation.',
                          'Desactiva para revisar más contexto de la app. Cambiar esto inicia una conversación nueva.',
                        ),
                      ),
                      value: _attachedTaskOnly,
                      onChanged: enabled
                          ? (value) => setState(() {
                              _attachedTaskOnly = value;
                              _history.clear();
                              _pending = null;
                            })
                          : null,
                    ),
                  if (planner)
                    ExpansionTile(
                      childrenPadding: const EdgeInsets.only(
                        top: 16,
                        bottom: 8,
                      ),
                      title: Text(
                        copy(
                          'Energy for this request',
                          'Energía para esta solicitud',
                        ),
                      ),
                      children: [
                        DropdownButtonFormField<double>(
                          isExpanded: true,
                          key: ValueKey('conversation-energy-$_generation'),
                          initialValue: _energy,
                          decoration: InputDecoration(
                            labelText: copy(
                              'Energy (optional)',
                              'Energía (opcional)',
                            ),
                          ),
                          hint: Text(copy('Not set', 'Sin indicar')),
                          items: [
                            DropdownMenuItem(
                              value: -1,
                              child: Text(copy('Not set', 'Sin indicar')),
                            ),
                            for (var percent = 0; percent <= 100; percent += 10)
                              DropdownMenuItem(
                                value: percent / 100,
                                child: Text('$percent%'),
                              ),
                            if (_energy != null &&
                                ![
                                  for (var i = 0; i <= 10; i++) i / 10,
                                ].contains(_energy))
                              DropdownMenuItem(
                                value: _energy,
                                child: Text('${(_energy! * 100).round()}%'),
                              ),
                          ],
                          onChanged: enabled
                              ? (v) =>
                                    setState(() => _energy = v == -1 ? null : v)
                              : null,
                        ),
                      ],
                    ),
                  if (!planner)
                    ExpansionTile(
                      key: const Key('conversation-advanced'),
                      childrenPadding: const EdgeInsets.only(
                        top: 16,
                        bottom: 8,
                      ),
                      title: Text(
                        copy('Advanced analysis', 'Análisis avanzado'),
                      ),
                      children: [
                        DropdownButtonFormField<SIV2Intent>(
                          isExpanded: true,
                          key: ValueKey('conversation-mode-$_generation'),
                          initialValue: _intent,
                          decoration: InputDecoration(
                            labelText: copy(
                              'Analysis mode',
                              'Modo de análisis',
                            ),
                          ),
                          items: SIV2Intent.values
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(_intentLabel(v)),
                                ),
                              )
                              .toList(),
                          onChanged: enabled
                              ? (v) => setState(() => _intent = v!)
                              : null,
                        ),
                        DropdownButtonFormField<SIV2TimeRange>(
                          isExpanded: true,
                          key: ValueKey('conversation-range-$_generation'),
                          initialValue: _range,
                          decoration: InputDecoration(
                            labelText: copy('Date range', 'Fechas'),
                          ),
                          items: SIV2TimeRange.values
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(_rangeLabel(v)),
                                ),
                              )
                              .toList(),
                          onChanged: enabled
                              ? (v) => setState(() => _range = v!)
                              : null,
                        ),
                        Wrap(
                          spacing: 8,
                          children: SIV2Source.values
                              .map(
                                (s) => FilterChip(
                                  label: Text(_sourceLabel(s)),
                                  selected: _sources.contains(s),
                                  onSelected: !enabled
                                      ? null
                                      : (selected) => setState(() {
                                          if (selected) {
                                            _sources = {..._sources, s};
                                          } else if (_sources.length > 1) {
                                            _sources = {..._sources}..remove(s);
                                          }
                                        }),
                                ),
                              )
                              .toList(),
                        ),
                        TextField(
                          key: const Key('conversation-entity-filter'),
                          controller: _filter,
                          enabled: enabled,
                          maxLength: 120,
                          decoration: InputDecoration(
                            labelText: copy(
                              'Filter saved titles',
                              'Filtrar títulos guardados',
                            ),
                          ),
                        ),
                        TextField(
                          key: const Key('conversation-scenario'),
                          controller: _scenario,
                          enabled: enabled,
                          maxLength: 500,
                          decoration: InputDecoration(
                            labelText: copy(
                              'Scenario to explore',
                              'Escenario que quieres explorar',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ..._history.map(
                    (turn) => Card(
                      color: turn['role'] == 'user'
                          ? const Color(0xFF162C40)
                          : const Color(0xFF101E2C),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              turn['role'] == 'user'
                                  ? copy('You', 'Tú')
                                  : copy('AI response', 'Respuesta de IA'),
                              style: const TextStyle(color: Colors.cyanAccent),
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
                                  copy('Report response', 'Reportar respuesta'),
                                ),
                              ),
                          ],
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
                            if (mounted && confirmed) {
                              setState(() => _pending = null);
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
                        labelText: copy(
                          'Your question or follow-up',
                          'Tu pregunta o continuación',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (ref.watch(voiceInputEnabledProvider)) ...[
                    IconButton(
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
                                await _voiceController.stopListening();
                                return;
                              }
                              _dictationDraftBase = _input.text;
                              final int revision =
                                  _voiceController.lifecycleRevision;
                              await startVoiceInputWithConsent(
                                context: context,
                                onStart: () => _voiceController.startListening(
                                  localeId: Localizations.localeOf(
                                    context,
                                  ).toLanguageTag(),
                                ),
                                consentStore: ref.read(
                                  voiceInputConsentStoreProvider,
                                ),
                                isCurrentRequest: () =>
                                    _voiceController.lifecycleRevision ==
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
                    tooltip: copy('Send to AI', 'Enviar a IA'),
                    onPressed: enabled && !listening ? () => _send() : null,
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

  String _intentLabel(SIV2Intent value) => switch (value) {
    SIV2Intent.answer => copy('Answer', 'Responder'),
    SIV2Intent.explain => copy('Explain', 'Explicar'),
    SIV2Intent.compare => copy('Compare', 'Comparar'),
    SIV2Intent.forecast => copy('Forecast', 'Proyección'),
    SIV2Intent.findConflict => copy('Find conflicts', 'Buscar conflictos'),
    SIV2Intent.counterfactual => copy('What would change?', '¿Qué cambiaría?'),
  };
  String _rangeLabel(SIV2TimeRange value) => switch (value) {
    SIV2TimeRange.today => copy('Today', 'Hoy'),
    SIV2TimeRange.sevenDays => copy('7 days', '7 días'),
    SIV2TimeRange.thirtyDays => copy('30 days', '30 días'),
    SIV2TimeRange.all => copy('All dates', 'Todas las fechas'),
  };
  String _sourceLabel(SIV2Source value) => switch (value) {
    SIV2Source.tasks => copy('Tasks', 'Tareas'),
    SIV2Source.goals => copy('Goals', 'Metas'),
    SIV2Source.milestones => copy('Milestones', 'Hitos'),
    SIV2Source.timeline => copy('Timeline', 'Historial'),
  };
}
