part of 'assistant_conversation_screen.dart';

/// Words shown by the conversation: failure messages, the preview of the
/// information a request carries, and the option labels.
extension _ConversationCopy on _AssistantConversationScreenState {
  String _failureText(String code) => switch (code) {
    'timing_context_missing' => copy(
      'I need one scheduled task and its local date to check this store-closing question. No credits were charged. Schedule or select the task, update the app if needed, then start a new request and review a new quote.',
      'Necesito una tarea programada y su fecha local para comprobar esta pregunta sobre el cierre de la tienda. No se cobraron créditos de IA. Programa o selecciona la tarea, actualiza la app si hace falta y luego inicia una solicitud nueva y revisa una cotización nueva.',
    ),
    'insufficient_credits' || 'credits_exhausted' => copy(
      'You do not have enough AI credits. No model answer was generated. No credits were charged. Add credits or wait for your allowance, then start a new request and review a new quote.',
      'No tienes suficientes créditos de IA. No se generó una respuesta del modelo. No se cobraron créditos. Añade créditos o espera tu asignación; después inicia una solicitud nueva y revisa una nueva cotización.',
    ),
    'request_completed' => copy(
      'This request already finished, but its reply is unavailable. Retrying did not charge you again. To ask again, start a new request and review a new quote.',
      'Esta solicitud ya terminó, pero la respuesta no está disponible. El reintento no te cobró de nuevo. Para preguntar otra vez, inicia una solicitud nueva y revisa una cotización nueva.',
    ),
    'quote_expired' || 'credit_quote_required' => copy(
      'The price expired. Start a new request to review a new quote.',
      'El precio caducó. Inicia otra solicitud para revisar una nueva cotización.',
    ),
    'request_not_saved' => copy(
      'This request could not be saved on this device, so it was not sent. No credits were charged. Your question is retained; try again. If this keeps happening, open Chat and use Clear conversation, then try again.',
      'No se pudo guardar esta solicitud en este dispositivo, así que no se envió. No se cobraron créditos. Tu pregunta se conserva; inténtalo de nuevo. Si sigue pasando, abre Chat y usa Borrar conversación; luego inténtalo de nuevo.',
    ),
    'quote_timeout' => copy(
      'The AI service took too long to provide a credit price. No paid request was confirmed. Your question is retained; start a new request to review a fresh quote.',
      'El servicio de IA tardó demasiado en proporcionar un precio en créditos. No se confirmó ninguna solicitud de pago. Tu pregunta se conserva; inicia una solicitud nueva para revisar una cotización nueva.',
    ),
    'request_timeout' => copy(
      'The AI service took too long to confirm a reply. Your question and the same priced request are retained. Retry the same request to avoid a second charge.',
      'El servicio de IA tardó demasiado en confirmar una respuesta. Se conservan tu pregunta y la misma solicitud con precio. Reintenta la misma solicitud para evitar un segundo cobro.',
    ),
    'daily_budget_exceeded' => copy(
      'You reached the rolling daily AI safety limit. No credits were charged. Your question is retained, but this priced request cannot be reused. Start a new request and review a new quote after the limit resets.',
      'Alcanzaste el límite diario móvil de seguridad de IA. No se cobraron créditos. Tu pregunta se conserva, pero esta solicitud con precio no se puede reutilizar. Inicia una solicitud nueva y revisa una nueva cotización cuando se restablezca el límite.',
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
    'request_refunded' ||
    'unsafe_upstream_response' ||
    'inconsistent_upstream_response' ||
    'upstream_ai_error' ||
    'truncated_upstream_response' ||
    'invalid_upstream_response' ||
    'empty_upstream_response' => copy(
      'The request ended without a usable reply and its credits were refunded. No credits were charged. Your question is retained; start a new request and review a new quote.',
      'La solicitud terminó sin una respuesta utilizable y se reembolsaron sus créditos. No se cobraron créditos. Tu pregunta se conserva; inicia una solicitud nueva y revisa una cotización nueva.',
    ),
    'response_withheld' => copy(
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

  String _contextPreview(ConversationPacket packet) {
    final data = Map<String, dynamic>.from(packet.toJson()['context'] as Map);
    final sourceNames =
        (data['selectedSources'] as List?)?.whereType<String>().toSet() ??
        <String>{};
    final includedSources = SIV2Source.values
        .where((source) => sourceNames.contains(source.name))
        .map(_sourceLabel)
        .join(', ');
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
        'Sources: ${includedSources.isEmpty ? 'just this chat' : includedSources}',
        'Fuentes: ${includedSources.isEmpty ? 'solo esta conversación' : includedSources}',
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
    SIV2Source.timeline => copy('Schedule', 'Agenda'),
  };
}
