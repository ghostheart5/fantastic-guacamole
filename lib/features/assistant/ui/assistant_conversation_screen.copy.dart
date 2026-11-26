part of 'assistant_conversation_screen.dart';

/// Answers in which the server speaks for the request id itself, after its
/// own record of every attempt: a denied reservation (kept with its reason
/// for a repeat of the same id), a refund, an already completed request, or
/// a charged reply this device withheld. Their charge statements hold even
/// when an earlier attempt of the same request was sent. Anything else (a
/// check before the reservation, or an error raised on this device) says
/// nothing about an earlier attempt.
const _answersForThisRequest = <String>{
  'insufficient_credits',
  'credits_exhausted',
  'daily_budget_exceeded',
  'provider_cost_budget_exceeded',
  'refunded_credits_outstanding',
  'request_completed',
  'request_refunded',
  'unsafe_upstream_response',
  'inconsistent_upstream_response',
  'upstream_ai_error',
  'truncated_upstream_response',
  'invalid_upstream_response',
  'empty_upstream_response',
  'response_withheld',
};

/// Words shown by the conversation: failure messages, the preview of the
/// information a request carries, and the option labels.
extension _ConversationCopy on _AssistantConversationScreenState {
  /// [balance] is the balance the server sent with this answer, if any.
  /// [sentForReply]: the request reached the paid step (it was confirmed
  /// and handed to the service for a reply), so a failure the service did
  /// not account for may have used credits. [priorAttempt]: this request was
  /// stored or retried, so an earlier attempt may already have been charged;
  /// only answers in which the server speaks for this request id may then say
  /// what was charged.
  String _failureText(
    String code, {
    int? balance,
    bool sentForReply = false,
    bool priorAttempt = false,
  }) => priorAttempt && !_answersForThisRequest.contains(code)
      ? _priorAttemptText(code)
      : _firstAttemptFailureText(
          code,
          balance: balance,
          sentForReply: sentForReply,
        );

  /// Shown when a stored or retried request fails without the server saying
  /// what happened to its charge.
  String _priorAttemptText(String code) {
    final reason = switch (code) {
      'quote_expired' || 'credit_quote_required' => copy(
        'The price for this request expired, so it cannot be retried.',
        'El precio de esta solicitud caducó, así que no se puede reintentar.',
      ),
      'unauthorized' || 'authentication_required' => copy(
        'Your sign-in needs renewing before AI chat can answer.',
        'Debes renovar tu inicio de sesión para que el chat con IA responda.',
      ),
      'rate_limit_exceeded' => copy(
        'Too many AI requests arrived at once.',
        'Llegaron demasiadas solicitudes de IA al mismo tiempo.',
      ),
      'authorization_changed' => copy(
        'Your account or AI consent changed, so this request was stopped.',
        'Cambió tu cuenta o consentimiento de IA, así que se detuvo esta solicitud.',
      ),
      'request_too_large' => copy(
        'This request is too large to send.',
        'Esta solicitud es demasiado grande para enviarla.',
      ),
      'internal_ai_access_required' || 'external_ai_disabled' => copy(
        'AI chat is not available for this account right now.',
        'El chat con IA no está disponible para esta cuenta en este momento.',
      ),
      _ => copy(
        'The AI service could not complete this request.',
        'El servicio de IA no pudo completar esta solicitud.',
      ),
    };
    return '$reason ${copy('This request may already have been sent, so it may have used credits. Check your balance before asking again. Your question is kept.', 'Puede que esta solicitud ya se haya enviado, así que es posible que haya usado créditos. Revisa tu saldo antes de volver a preguntar. Tu pregunta se conserva.')}';
  }

  String _firstAttemptFailureText(
    String code, {
    int? balance,
    required bool sentForReply,
  }) => switch (code) {
    'timing_context_missing' => copy(
      'I need one scheduled task and its local date to check this store-closing question. No credits were charged. Schedule or select the task, update the app if needed, then tap send to ask again as a new message.',
      'Necesito una tarea programada y su fecha local para comprobar esta pregunta sobre el cierre de la tienda. No se cobraron créditos de IA. Programa o selecciona la tarea, actualiza la app si hace falta y luego toca enviar para preguntar de nuevo como un mensaje nuevo.',
    ),
    'insufficient_credits' || 'credits_exhausted' => _outOfCreditsText(
      balance: balance,
      needed: conversationMessageCredits,
    ),
    'refunded_credits_outstanding' => copy(
      'AI chat is paused for this account because credits from a refunded purchase are still owed. No credits were charged. Your question is kept.',
      'El chat con IA está en pausa en esta cuenta porque aún se deben créditos de una compra reembolsada. No se cobraron créditos. Tu pregunta se conserva.',
    ),
    'request_completed' => copy(
      'This request already finished, but its reply is unavailable. Retrying did not charge you again. To ask again, tap send; it is charged as a new message.',
      'Esta solicitud ya terminó, pero la respuesta no está disponible. El reintento no te cobró de nuevo. Para preguntar otra vez, toca enviar; se cobra como un mensaje nuevo.',
    ),
    'quote_expired' || 'credit_quote_required' => copy(
      'The price expired before the message was sent. No credits were charged. Your question is kept; tap send to try again.',
      'El precio caducó antes de enviar el mensaje. No se cobraron créditos. Tu pregunta se conserva; toca enviar para intentarlo de nuevo.',
    ),
    'request_too_large' || 'context_too_large' => _tooLargeText,
    // Before anything was handed on, invalid_request means the request was
    // over the size the server accepts and was not built.
    'invalid_request' when !sentForReply => _tooLargeText,
    'unauthorized' || 'authentication_required' => copy(
      'Your sign-in needs renewing before AI chat can answer. Nothing was charged. Sign in again, then tap send. Your question is kept.',
      'Debes renovar tu inicio de sesión para que el chat con IA responda. No se cobró nada. Inicia sesión de nuevo y luego toca enviar. Tu pregunta se conserva.',
    ),
    // Refused by the server before any charge. (release_unavailable is not
    // here: it can also be raised after a reply was charged.)
    'internal_ai_access_required' || 'external_ai_disabled' => copy(
      'AI chat is not available for this account right now. Nothing was charged. Your question is kept. The free assistant on this device works without credits.',
      'El chat con IA no está disponible para esta cuenta en este momento. No se cobró nada. Tu pregunta se conserva. El asistente gratis en este dispositivo funciona sin créditos.',
    ),
    'attachment_unavailable' => copy(
      'The attached task is no longer available. Nothing was sent for a reply. Nothing was charged. Attach another task or remove the attachment, then tap send.',
      'La tarea adjunta ya no está disponible. No se envió nada para responder. No se cobró nada. Adjunta otra tarea o quita el adjunto y luego toca enviar.',
    ),
    'request_not_saved' => copy(
      'This request could not be saved on this device, so it was not sent. No credits were charged. Your question is retained; try again. If this keeps happening, open Chat and use Clear conversation, then try again.',
      'No se pudo guardar esta solicitud en este dispositivo, así que no se envió. No se cobraron créditos. Tu pregunta se conserva; inténtalo de nuevo. Si sigue pasando, abre Chat y usa Borrar conversación; luego inténtalo de nuevo.',
    ),
    // Saving reported an error after the write was handed to storage, and
    // reading it back failed too: both outcomes are possible.
    'request_storage_uncertain' => copy(
      'This request may or may not have been saved on this device; that could not be checked. If it was saved, it is sent once and its reply appears when this screen opens again, using its credits. If it was not, nothing was sent or charged. Your question is kept.',
      'Puede que esta solicitud se haya guardado en este dispositivo o no; no se pudo comprobar. Si se guardó, se envía una vez y su respuesta aparece cuando vuelvas a abrir esta pantalla, usando sus créditos. Si no se guardó, no se envió ni se cobró nada. Tu pregunta se conserva.',
    ),
    'quote_timeout' => copy(
      'The AI service took too long to check the credit price. Nothing was sent for a reply and nothing was charged. Your question is retained; tap send to try again.',
      'El servicio de IA tardó demasiado en comprobar el precio en créditos. No se envió nada para responder y no se cobró nada. Tu pregunta se conserva; toca enviar para intentarlo de nuevo.',
    ),
    'request_timeout' => copy(
      'The AI service took too long to confirm a reply. Your question and the same priced request are retained. Retry the same request to avoid a second charge.',
      'El servicio de IA tardó demasiado en confirmar una respuesta. Se conservan tu pregunta y la misma solicitud con precio. Reintenta la misma solicitud para evitar un segundo cobro.',
    ),
    'daily_budget_exceeded' => copy(
      'You reached the rolling daily AI safety limit. No credits were charged. Your question is retained, but this priced request cannot be reused. After the limit resets, tap send to ask again as a new message.',
      'Alcanzaste el límite diario móvil de seguridad de IA. No se cobraron créditos. Tu pregunta se conserva, pero esta solicitud con precio no se puede reutilizar. Cuando se restablezca el límite, toca enviar para preguntar de nuevo como un mensaje nuevo.',
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
    // Also raised after the service answered, so the charge is not known.
    'authorization_changed' => copy(
      'Your account or AI consent changed. This request was stopped.${sentForReply ? ' It may have used credits; check your balance before asking again.' : ''}',
      'Cambió tu cuenta o consentimiento de IA. Se detuvo esta solicitud.${sentForReply ? ' Es posible que haya usado créditos; revisa tu saldo antes de volver a preguntar.' : ''}',
    ),
    'request_refunded' ||
    'unsafe_upstream_response' ||
    'inconsistent_upstream_response' ||
    'upstream_ai_error' ||
    'truncated_upstream_response' ||
    'invalid_upstream_response' ||
    'empty_upstream_response' => copy(
      'The request ended without a usable reply and its credits were refunded. No credits were charged. Your question is retained; tap send to ask again as a new message.',
      'La solicitud terminó sin una respuesta utilizable y se reembolsaron sus créditos. No se cobraron créditos. Tu pregunta se conserva; toca enviar para preguntar de nuevo como un mensaje nuevo.',
    ),
    // The server confirmed the reply and its charge; this device's check
    // withheld it.
    'response_withheld' => copy(
      'The reply did not pass the response check, so it is not shown. It has not been replaced with a stock answer. This message used its credits.${balance == null ? '' : ' Credits left: $balance.'}',
      'La respuesta no superó la comprobación, así que no se muestra. No se sustituyó por una respuesta prefabricada. Este mensaje usó sus créditos.${balance == null ? '' : ' Créditos restantes: $balance.'}',
    ),
    // Codes such as credit_settlement_failed, release_unavailable or
    // unconfirmed_result can follow a charged reply.
    _ when sentForReply => copy(
      'The AI service could not complete this request, and it may have used credits. Check your balance before asking again. Your question is kept.',
      'El servicio de IA no pudo completar esta solicitud y es posible que haya usado créditos. Revisa tu saldo antes de volver a preguntar. Tu pregunta se conserva.',
    ),
    // Only the price was asked for: that never charges.
    _ => copy(
      'The AI service could not complete this request. Nothing was sent for a reply and nothing was charged. Your question is kept; you can try again.',
      'El servicio de IA no pudo completar esta solicitud. No se envió nada para responder y no se cobró nada. Tu pregunta se conserva; puedes intentarlo de nuevo.',
    ),
  };

  String get _tooLargeText => copy(
    'This question and the information with it are too large to send. Nothing was sent for a reply. Nothing was charged. Shorten the question or choose less information, then tap send.',
    'Esta pregunta y la información que la acompaña son demasiado grandes para enviarlas. No se envió nada para responder. No se cobró nada. Acorta la pregunta o elige menos información y luego toca enviar.',
  );

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
        .followedBy(
          ConversationExtraSource.values
              .where((source) => sourceNames.contains(source.name))
              .map(_extraLabel),
        )
        .join(', ');
    final sentIntent =
        SIV2Intent.values.where((i) => i.name == data['mode']).firstOrNull ??
        _intent;
    final lines = <String>[
      if (data['contextScope'] == 'attachedTaskOnly')
        copy(
          'Context: attached task only. Other records and emotional state are excluded.',
          'Contexto: solo la tarea adjunta. Se excluyen otros registros y el estado emocional.',
        ),
      // The analysis the request carries, which follows the question.
      copy(
        'Analysis: ${_intentLabel(sentIntent)}',
        'Análisis: ${_intentLabel(sentIntent)}',
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
      // The extra sources (habits, recent results, goal progress).
      'cadence': copy('Repeats', 'Se repite'),
      'checkInsLast14Days': copy(
        'Check-ins in the last 14 days',
        'Cumplimientos en los últimos 14 días',
      ),
      'streakPeriods': copy(
        'Current streak (days, weeks or months in a row, since the last change to how often it repeats)',
        'Racha actual (días, semanas o meses seguidos, desde el último cambio de frecuencia)',
      ),
      'outcome': copy('Result', 'Resultado'),
      'at': copy('Date and time', 'Fecha y hora'),
      'tasksDone': copy('Linked tasks done', 'Tareas vinculadas hechas'),
      'tasksOpen': copy('Linked tasks open', 'Tareas vinculadas abiertas'),
      'milestonesDone': copy('Milestones done', 'Hitos hechos'),
      'milestonesOpen': copy('Milestones open', 'Hitos abiertos'),
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
    final unreadable = (data['unavailableSources'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    for (final source in ConversationExtraSource.values) {
      if (!sourceNames.contains(source.name)) continue;
      // The heading names the window the request really carries: the key it
      // was sent under says it.
      final key = source.contextKeys.firstWhere(
        data.containsKey,
        orElse: () => source.contextKeys.first,
      );
      lines.add('\n${_extraHeading(key)}');
      final records = data[key];
      if (unreadable.contains(source.name)) {
        lines.add(
          copy(
            'Could not be read on this device.',
            'No se pudo leer en este dispositivo.',
          ),
        );
      }
      if (records is! List || records.isEmpty) {
        if (!unreadable.contains(source.name)) {
          lines.add(copy('None found.', 'No se encontró nada.'));
        }
        continue;
      }
      for (final item in records.whereType<Map<Object?, Object?>>()) {
        record({
          ...item,
          if (item['cadence'] case final String cadence)
            'cadence': switch (cadence) {
              'weekly' => copy('Weekly', 'Semanal'),
              'monthly' => copy('Monthly', 'Mensual'),
              _ => copy('Daily', 'Diario'),
            },
          if (item['outcome'] case final String outcome)
            'outcome': outcome == 'skipped'
                ? copy('Skipped', 'Omitida')
                : copy('Finished', 'Terminada'),
        });
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
          'Your selected emotional state: ${_emotionName(emotion)}',
          'Tu estado emocional seleccionado: ${_emotionName(emotion)}',
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

  /// The window of recent results, in words, from the key it is sent under.
  String _recentWindowWords(ConversationRecentWindow window) =>
      switch (window) {
        ConversationRecentWindow.today => copy('today', 'hoy'),
        ConversationRecentWindow.last7Days => copy(
          'last 7 days',
          'últimos 7 días',
        ),
        ConversationRecentWindow.last14Days => copy(
          'last 14 days',
          'últimos 14 días',
        ),
      };

  String _extraHeading(String key) {
    for (final window in ConversationRecentWindow.values) {
      if (window.contextKey == key) {
        return copy(
          'Recent results (${_recentWindowWords(window)})',
          'Resultados recientes (${_recentWindowWords(window)})',
        );
      }
    }
    return switch (key) {
      'goalProgressAllTime' => copy(
        'Goal progress (all time)',
        'Progreso de metas (todo el tiempo)',
      ),
      _ => copy(
        'Habits (check-ins: last 14 days)',
        'Hábitos (cumplimientos: últimos 14 días)',
      ),
    };
  }

  String _sourceLabel(SIV2Source value) => switch (value) {
    SIV2Source.tasks => copy('Tasks', 'Tareas'),
    SIV2Source.goals => copy('Goals', 'Metas'),
    SIV2Source.milestones => copy('Milestones', 'Hitos'),
    SIV2Source.timeline => copy('Schedule', 'Agenda'),
  };
}
