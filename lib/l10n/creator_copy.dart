/// Creator display copy. Canonical entity values and entered content stay unchanged.
class CreatorCopy {
  const CreatorCopy(this.isSpanish);
  final bool isSpanish;

  String get title => isSpanish ? 'Creador' : 'Creator';
  String get subtitle => isSpanish
      ? 'Convierte una intención en una acción conectada.'
      : 'Turn intention into connected action.';
  String get eyebrow => isSpanish ? 'Acción conectada' : 'Connected action';
  String get manageRhythms =>
      isSpanish ? 'Gestionar Ritmos Diarios' : 'Manage Daily Rhythms';
  String get savedSnack => isSpanish
      ? 'Confirmado y guardado una sola vez. Puedes deshacerlo aquí.'
      : 'Confirmed and saved exactly once. Undo is available here.';
  String get reviewChanges => isSpanish ? 'REVISAR CAMBIOS' : 'REVIEW CHANGES';
  String get draftPreview =>
      isSpanish ? 'VISTA PREVIA DEL BORRADOR' : 'PLANNER DRAFT PREVIEW';
  String get draftBoundary => isSpanish
      ? 'No se ha guardado nada. Revisa y edita el formulario; después pulsa REVISAR CAMBIOS para abrir la confirmación del Creador.'
      : 'Nothing has been saved. Review and edit the prefilled form, then press REVIEW CHANGES to open Creator confirmation.';
  String get discardPreview =>
      isSpanish ? 'Descartar vista previa' : 'Discard preview';
  String get confirmTitle =>
      isSpanish ? 'CONFIRMAR CAMBIOS DEL CREADOR' : 'CONFIRM CREATOR CHANGES';
  String get confirmBoundary => isSpanish
      ? 'No se guarda nada hasta que confirmes la operación seleccionada.'
      : 'Nothing is saved until you confirm the selected operation below.';
  String get expires => isSpanish ? 'Caduca' : 'Expires';
  String get contextReview => isSpanish
      ? 'REVISIÓN DEL CONTEXTO AUTORIZADO'
      : 'GOVERNED CONTEXT REVIEW';
  String get contextBoundary => isSpanish
      ? 'Se revisó el contexto pertinente que compartiste. La propuesta no se cambió sin avisarte; cualquier conflicto requiere tu confirmación.'
      : 'Relevant user-reported context was checked. The proposal was not silently rewritten; any conflict requires your confirmation.';
  String get confirming => isSpanish ? 'CONFIRMANDO…' : 'CONFIRMING…';
  String get confirmSelected =>
      isSpanish ? 'CONFIRMAR SELECCIÓN' : 'CONFIRM SELECTED';
  String get editDraft => isSpanish ? 'Editar borrador' : 'Edit draft';
  String get cancel => isSpanish ? 'Cancelar' : 'Cancel';
  String get notPresent => isSpanish ? 'No existe' : 'Not present';
  String get noLinkedGoal =>
      isSpanish ? 'Sin meta vinculada' : 'No linked goal';
  String get unavailableGoal => isSpanish
      ? 'La meta vinculada no está disponible'
      : 'Linked goal unavailable';
  String get noEstimate => isSpanish ? 'Sin estimación' : 'No estimate';
  String get unscheduled => isSpanish ? 'Sin programar' : 'Unscheduled';
  String get noDeadline => isSpanish ? 'Sin fecha límite' : 'No deadline';
  String get noTargetDate =>
      isSpanish ? 'Sin fecha objetivo' : 'No target date';
  String get creationUndone =>
      isSpanish ? 'CREACIÓN DESHECHA' : 'CREATION UNDONE';
  String get creationSaved =>
      isSpanish ? 'CREACIÓN GUARDADA' : 'CREATION SAVED';
  String get undo => isSpanish ? 'Deshacer creación' : 'Undo creation';
  String get openTimeline =>
      isSpanish ? 'Abrir Línea de Tiempo' : 'Open Timeline';
  String get newItem => isSpanish ? 'Nuevo elemento' : 'New item';
  String get create => isSpanish ? 'CREAR' : 'CREATE';
  String get titleHint => isSpanish ? 'Título *' : 'Title *';
  String get titleSemantic =>
      isSpanish ? 'Título, obligatorio' : 'Title, required';
  String get bodyHint => isSpanish ? 'Contenido (opcional)' : 'Body (optional)';
  String get descriptionHint =>
      isSpanish ? 'Descripción (opcional)' : 'Description (optional)';
  String get working => isSpanish ? 'PROCESANDO...' : 'WORKING...';
  String get activeGoal => isSpanish ? 'META ACTIVA' : 'ACTIVE GOAL';
  String get estimate => isSpanish ? 'DURACIÓN ESTIMADA' : 'ESTIMATED DURATION';
  String get schedule => isSpanish ? 'PROGRAMACIÓN' : 'SCHEDULE';
  String get pickSchedule =>
      isSpanish ? 'Elegir fecha y hora...' : 'Schedule date and time...';
  String get deadline => isSpanish ? 'FECHA LÍMITE' : 'DEADLINE';
  String get pickDeadline =>
      isSpanish ? 'Añadir fecha límite...' : 'Add deadline...';
  String get targetDate => isSpanish ? 'FECHA OBJETIVO' : 'TARGET DATE';
  String get pickTargetDate =>
      isSpanish ? 'Añadir fecha objetivo...' : 'Add target date...';
  String get cadenceHeading =>
      isSpanish ? 'FRECUENCIA / REPETICIÓN' : 'CADENCE / RECURRENCE';
  String get priority => isSpanish ? 'PRIORIDAD' : 'PRIORITY';
  String get low => isSpanish ? 'BAJA' : 'LOW';
  String get balanced => isSpanish ? 'EQUILIBRADA' : 'BALANCED';
  String get critical => isSpanish ? 'CRÍTICA' : 'CRITICAL';
  String get targetCount =>
      isSpanish ? 'REPETICIONES OBJETIVO' : 'TARGET COUNT';
  String get decreaseCount =>
      isSpanish ? 'Reducir repeticiones objetivo' : 'Decrease target count';
  String get increaseCount =>
      isSpanish ? 'Aumentar repeticiones objetivo' : 'Increase target count';
  String get firstScheduleRequired => isSpanish
      ? 'Elige una fecha y hora para que tu primera tarea aparezca en la Línea de Tiempo.'
      : 'Choose a date and time so your first task can appear on Timeline.';

  String kind(String name) => switch (name) {
    'task' => isSpanish ? 'Tarea' : 'Task',
    'goal' => isSpanish ? 'Meta' : 'Goal',
    'habit' => isSpanish ? 'Ritmo diario' : 'Daily Rhythm',
    'note' => isSpanish ? 'Nota' : 'Note',
    _ => isSpanish ? 'Elemento' : 'Item',
  };
  String createAction(String name) => '$create ${kind(name).toUpperCase()}';
  String details(String name) => isSpanish
      ? 'DETALLES: ${kind(name).toUpperCase()}'
      : '${kind(name).toUpperCase()} DETAILS';
  String titleRequired(String name) => isSpanish
      ? 'Añade un título antes de crear ${name == 'habit' ? 'el' : 'la'} ${kind(name).toLowerCase()}.'
      : 'Add a title before creating the ${kind(name).toLowerCase()}.';
  String saveFailed(String name) => isSpanish
      ? 'No se pudo guardar ${name == 'habit' ? 'el' : 'la'} ${kind(name).toLowerCase()}. Tu texto sigue aquí; vuelve a intentarlo.'
      : 'The ${kind(name).toLowerCase()} could not be saved. Your entry is still here - retry.';
  String setPriority(int level) => isSpanish
      ? 'Elegir nivel de prioridad $level'
      : 'Set priority level $level';
  String clearDate(String label) => isSpanish
      ? 'Borrar ${label.toLowerCase()}'
      : 'Clear ${label.toLowerCase()}';
  String cadence(String name) => switch (name) {
    'daily' => isSpanish ? 'Diario' : 'Daily',
    'weekly' => isSpanish ? 'Semanal' : 'Weekly',
    'monthly' => isSpanish ? 'Mensual' : 'Monthly',
    _ => name,
  };
  String repetitions(int count, String cadenceName) {
    final period = switch (cadenceName) {
      'daily' => isSpanish ? 'día' : 'day',
      'weekly' => isSpanish ? 'semana' : 'week',
      _ => isSpanish ? 'mes' : 'month',
    };
    return isSpanish
        ? '$count ${count == 1 ? 'vez' : 'veces'} por $period'
        : '$count ${count == 1 ? 'time' : 'times'} per $period';
  }

  String minutes(int count) => isSpanish
      ? '$count ${count == 1 ? 'minuto' : 'minutos'}'
      : '$count ${count == 1 ? 'minute' : 'minutes'}';
  String duration(Duration value) {
    final count = value.inMinutes;
    if (count < 60) return minutes(count);
    final hours = count ~/ 60;
    final unit = isSpanish
        ? (hours == 1 ? 'hora' : 'horas')
        : (hours == 1 ? 'hour' : 'hours');
    return '$hours $unit ${count % 60 == 0 ? '' : '${count % 60} min'}'.trim();
  }

  String field(String name) => !isSpanish
      ? name
      : switch (name) {
          'Title' => 'Título',
          'Type' => 'Tipo',
          'Priority' => 'Prioridad',
          'Active goal' => 'Meta activa',
          'Estimated duration' => 'Duración estimada',
          'Schedule' => 'Programación',
          'Deadline' => 'Fecha límite',
          'Description' => 'Descripción',
          'Target date' => 'Fecha objetivo',
          'Cadence' => 'Frecuencia',
          'Target count' => 'Repeticiones objetivo',
          'Body' => 'Contenido',
          _ => name,
        };
  String changeCount(int count, bool undone) => isSpanish
      ? '$count ${count == 1 ? 'cambio' : 'cambios'} ${undone ? (count == 1 ? 'deshecho' : 'deshechos') : (count == 1 ? 'guardado' : 'guardados')}.'
      : '$count ${count == 1 ? 'change' : 'changes'} ${undone ? 'undone' : 'saved'}.';
  String draftGuidance(String reason, String evidence) => isSpanish
      ? 'Por qué este plan: $reason\n\nEvidencia revisada:\n$evidence'
      : 'Why this plan: $reason\n\nEvidence reviewed:\n$evidence';
  String draftEffort(int count, String tradeoff) => isSpanish
      ? 'Esfuerzo estimado: ${minutes(count)}. Lo que implica el plan: $tradeoff'
      : 'Estimated effort: ${minutes(count)}. Planner tradeoff: $tradeoff';

  /// Only app-owned prefixes are translated. Reported values remain verbatim.
  String evidence(String value) {
    if (!isSpanish) return value;
    final separator = value.indexOf(': ');
    if (separator < 0) return value;
    final label = switch (value.substring(0, separator)) {
      'role' => 'Rol',
      'value' => 'Valor',
      'currentPriority' => 'Prioridad actual',
      'lifeArea' => 'Área de vida',
      'presentCapacity' => 'Capacidad actual',
      'preferredSupportStyle' => 'Apoyo preferido',
      'boundary' => 'Límite',
      'importantRelationship' => 'Relación importante',
      'commitment' => 'Compromiso',
      'outcomeHistory' => 'Historial de resultados',
      _ => null,
    };
    return label == null ? value : '$label${value.substring(separator)}';
  }

  String warning(String value) {
    if (!isSpanish) return 'Warning: $value';
    final capacity = RegExp(
      r'^The (\d+)-minute estimate exceeds the fresh user-reported (\d+)-minute capacity\.$',
    ).firstMatch(value);
    final translated = capacity == null
        ? switch (value) {
            'This proposal conflicts with an explicit boundary.' =>
              'Esta propuesta entra en conflicto con un límite que indicaste.',
            'This proposal matches a fresh user-reported commitment; confirm timing and duplication before saving.' =>
              'Esta propuesta coincide con un compromiso que indicaste recientemente; confirma el horario y comprueba que no esté duplicado antes de guardar.',
            _ => value,
          }
        : 'La estimación de ${capacity[1]} minutos supera la capacidad de ${capacity[2]} minutos que indicaste recientemente.';
    return 'Aviso: $translated';
  }

  /// Translate known handshake messages at presentation time. Signed previews,
  /// account bindings, receipts, and unknown diagnostic details stay unchanged.
  String message(String value) {
    if (!isSpanish) return value;
    final fixed = _messages[value];
    if (fixed != null) return fixed;
    for (final name in ['task', 'goal', 'habit', 'note']) {
      final english = const CreatorCopy(false).kind(name).toLowerCase();
      final noun = kind(name).toLowerCase();
      final article = name == 'habit' ? 'el' : 'la';
      final ofArticle = name == 'habit' ? 'del' : 'de la';
      final selected = name == 'habit' ? 'confirmado' : 'confirmada';
      final templates = <String, String>{
        'Review the exact selected change and its governed Person Context warnings. The proposed $english was not silently rewritten. Explicit confirmation is required; nothing has been saved yet.':
            'Revisa el cambio seleccionado y los avisos sobre tu contexto autorizado. No se modificó $article $noun sin avisarte. Se requiere tu confirmación; aún no se ha guardado nada.',
        'The saved replay record does not match the confirmed $english. Nothing was changed.':
            'El registro guardado no coincide con $article $noun $selected. No se cambió nada.',
        'The target $english identity is already used by different data. Nothing was changed.':
            'El identificador $ofArticle $noun ya corresponde a otros datos. No se cambió nada.',
        'The undo record no longer matches the confirmed $english. Nothing was changed.':
            'El registro para deshacer ya no coincide con $article $noun $selected. No se cambió nada.',
        'The created $english changed after confirmation, so automatic undo was blocked.':
            'Se modificó $article $noun después de confirmar. Para proteger esos cambios, se bloqueó la acción de deshacer.',
        'This confirmation was already applied. No duplicate $english was created.':
            'Esta confirmación ya se aplicó. No se duplicó $article $noun.',
      };
      if (templates.containsKey(value)) return templates[value]!;
    }
    const account =
        'Creator confirmation requires a verified account boundary.';
    if (value == '$account Nothing was saved.') {
      return 'Debes tener una cuenta verificada para confirmar. No se guardó nada.';
    }
    if (value == '$account The saved item was not changed.') {
      return 'Debes tener una cuenta verificada para deshacer. El elemento guardado no cambió.';
    }
    return value;
  }

  static const _messages = <String, String>{
    'Review the exact selected change. Nothing has been saved yet.':
        'Revisa el cambio seleccionado. Aún no se ha guardado nada.',
    'Select at least one operation to enable confirmation.':
        'Selecciona al menos una operación para poder confirmar.',
    'Selection updated. Review the bound diff before confirming.':
        'Selección actualizada. Revisa los cambios antes de confirmar.',
    'No bound Creator operation is selected. Nothing was saved.':
        'No hay ninguna operación del Creador seleccionada. No se guardó nada.',
    'Confirmation expired. The preview was refreshed; review it again. Nothing was saved.':
        'La confirmación caducó. Se actualizó la vista previa; revísala de nuevo. No se guardó nada.',
    'Confirmation binding did not match the displayed diff. Nothing was saved.':
        'La confirmación no coincide con los cambios mostrados. No se guardó nada.',
    'Creator data changed after this preview. Review the refreshed version before confirming. Nothing was saved.':
        'Los datos cambiaron después de esta vista previa. Revisa la versión actualizada antes de confirmar. No se guardó nada.',
    'Applying only the selected, confirmed operation…':
        'Aplicando solo la operación seleccionada y confirmada…',
    'Creator could not finish the confirmed operation. Review the current data before retrying.':
        'No se pudo completar la operación confirmada. Revisa los datos actuales antes de volver a intentarlo.',
    'Saved exactly once from the selected confirmation.':
        'Se guardó una sola vez a partir de tu confirmación.',
    'Undo is bound to another account. The saved item was not changed.':
        'Esta acción de deshacer corresponde a otra cuenta. El elemento guardado no cambió.',
    'The undo window expired. The saved item was not changed.':
        'El plazo para deshacer caducó. El elemento guardado no cambió.',
    'Undo could not complete. The current item state was preserved.':
        'No se pudo deshacer la creación. Se conservó el estado actual del elemento.',
    'Creation undone. Repeated undo requests will not mutate data again.':
        'Creación deshecha. Repetir esta solicitud no volverá a modificar los datos.',
    'Person context changed after this preview. Stage and review a new proposal before confirming. Nothing was saved.':
        'Tu contexto cambió después de esta vista previa. Prepara y revisa una nueva propuesta antes de confirmar. No se guardó nada.',
    'This confirmation was already applied. No duplicate items were created.':
        'Esta confirmación ya se aplicó. No se crearon elementos duplicados.',
  };
}
