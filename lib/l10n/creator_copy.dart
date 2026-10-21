/// Creator display copy. Canonical entity values and entered content stay unchanged.
class CreatorCopy {
  const CreatorCopy(this.isSpanish);
  final bool isSpanish;

  String get title => isSpanish ? 'Añadir algo' : 'Add something';
  String get back => isSpanish ? 'Volver a Hoy' : 'Back to Today';
  String get subtitle => isSpanish
      ? 'Ponle un nombre. Añade detalles solo si los necesitas.'
      : 'Give it a name. Add details only if you need them.';
  String get eyebrow => isSpanish
      ? 'Un lugar para tus ideas y planes'
      : 'A place for your thoughts and plans';
  String get manageRhythms => isSpanish ? 'Gestionar hábitos' : 'Manage habits';
  String get savedSnack => isSpanish
      ? 'Guardado. Puedes deshacerlo aquí.'
      : 'Saved. You can undo it here.';
  String get reviewChanges =>
      isSpanish ? 'Revisar antes de guardar' : 'Review before saving';
  String get draftPreview =>
      isSpanish ? 'Borrador sugerido' : 'Suggested draft';
  String get draftBoundary => isSpanish
      ? 'Esto es un borrador. Cambia lo que quieras y elige Revisar antes de guardar. Aún no se guardó nada.'
      : 'This is a draft. Edit anything you want, then choose Review before saving. Nothing is saved yet.';
  String get discardPreview =>
      isSpanish ? 'Descartar vista previa' : 'Discard preview';
  String get confirmTitle => isSpanish ? '¿Quieres guardar?' : 'Ready to save?';
  String get confirmBoundary => isSpanish
      ? 'Revisa el cambio seleccionado. Confirma para guardarlo.'
      : 'Check the selected change below. Confirm to save it.';
  String get expires => isSpanish ? 'Caduca' : 'Expires';
  String get contextReview => isSpanish
      ? 'Revisión de tus preferencias'
      : 'Check against your preferences';
  String get contextBoundary => isSpanish
      ? 'Revisamos los detalles que compartiste. El borrador no cambió. Revisa los conflictos antes de confirmar.'
      : 'We checked details you shared. The draft is unchanged. Review any conflicts before confirming.';
  String get confirming => isSpanish ? 'Guardando…' : 'Saving…';
  String get confirmSelected =>
      isSpanish ? 'Guardar cambios seleccionados' : 'Save selected changes';
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
  String get creationUndone => isSpanish ? 'Guardado deshecho' : 'Save undone';
  String get creationSaved => isSpanish ? 'Guardado' : 'Saved';
  String get undo => isSpanish ? 'Deshacer guardado' : 'Undo save';
  String get openTimeline => isSpanish ? 'Abrir agenda' : 'Open schedule';
  String get browseSavedTasks =>
      isSpanish ? 'Ver tareas guardadas' : 'Browse saved tasks';
  String browseSavedItem(String kind) => switch (kind) {
    'habit' => isSpanish ? 'Ver h\u00e1bitos' : 'Open habits',
    'goal' => isSpanish ? 'Ver metas' : 'View goals',
    'note' => isSpanish ? 'Ver notas' : 'View notes',
    _ => browseSavedTasks,
  };
  String get newItem => isSpanish ? 'Nuevo elemento' : 'New item';
  String get create => isSpanish ? 'Qué quieres guardar' : 'What to save';
  String get taskOptions =>
      isSpanish ? 'Opciones de la tarea (opcional)' : 'Task options (optional)';
  String get taskOptionsHint => isSpanish
      ? 'Fecha, duración, repetición o meta. Puedes cambiarlas después.'
      : 'Date, duration, repeat, or goal. You can change these later.';
  String get titleHint => isSpanish ? 'Título *' : 'Title *';
  String get titleSemantic =>
      isSpanish ? 'Título, obligatorio' : 'Title, required';
  String get bodyHint => isSpanish ? 'Contenido (opcional)' : 'Body (optional)';
  String get descriptionHint =>
      isSpanish ? 'Descripción (opcional)' : 'Description (optional)';
  String get working => isSpanish ? 'Procesando…' : 'Working…';
  String get activeGoal => isSpanish
      ? 'Vincular a una meta (opcional)'
      : 'Link to a goal (optional)';
  String get estimate => isSpanish ? '¿Cuánto tiempo?' : 'About how long?';
  String get schedule =>
      isSpanish ? 'Cuándo hacerlo (opcional)' : 'When to work on it (optional)';
  String get requiredSchedule =>
      isSpanish ? 'Cuándo hacerlo' : 'When to work on it';
  String get pickSchedule =>
      isSpanish ? 'Elegir fecha y hora...' : 'Schedule date and time...';
  String get deadline =>
      isSpanish ? 'Fecha límite (opcional)' : 'Due date (optional)';
  String get pickDeadline =>
      isSpanish ? 'Añadir fecha límite...' : 'Add deadline...';
  String get targetDate =>
      isSpanish ? 'Fecha objetivo (opcional)' : 'Target date (optional)';
  String get pickTargetDate =>
      isSpanish ? 'Añadir fecha objetivo...' : 'Add target date...';
  String get cadenceHeading =>
      isSpanish ? '¿Con qué frecuencia?' : 'How often?';
  String get priority => isSpanish ? 'PRIORIDAD' : 'PRIORITY';
  String get low => isSpanish ? 'BAJA' : 'LOW';
  String get balanced => isSpanish ? 'Media' : 'Medium';
  String get critical => isSpanish ? 'Alta' : 'High';
  String get targetCount => isSpanish ? '¿Cuántas veces?' : 'How many times?';
  String get decreaseCount =>
      isSpanish ? 'Reducir repeticiones objetivo' : 'Decrease target count';
  String get increaseCount =>
      isSpanish ? 'Aumentar repeticiones objetivo' : 'Increase target count';
  String get firstScheduleRequired => isSpanish
      ? 'Elige fecha y hora para ver esta tarea en tu agenda.'
      : 'Choose a date and time to see this task in your schedule.';

  String kind(String name) => switch (name) {
    'task' => isSpanish ? 'Tarea' : 'Task',
    'goal' => isSpanish ? 'Meta' : 'Goal',
    'habit' => isSpanish ? 'Hábito' : 'Habit',
    'note' => isSpanish ? 'Nota' : 'Note',
    _ => isSpanish ? 'Elemento' : 'Item',
  };
  String createAction(String name) => isSpanish
      ? 'Guardar ${kind(name).toLowerCase()}'
      : 'Save ${kind(name).toLowerCase()}';
  String details(String name) => isSpanish
      ? 'Detalles: ${kind(name).toLowerCase()}'
      : '${kind(name)} details';
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

  /// Explain known handshake messages at presentation time. Signed previews,
  /// account bindings, receipts, and unknown diagnostic details stay unchanged.
  String message(String value) {
    if (!isSpanish) return _plainEnglishMessages[value] ?? value;
    final fixed = _messages[value];
    if (fixed != null) return fixed;
    for (final name in ['task', 'goal', 'habit', 'note']) {
      final english = name == 'habit' ? 'daily rhythm' : name;
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

  static const _plainEnglishMessages = <String, String>{
    'Review the exact selected change. Nothing has been saved yet.':
        'Check the selected change. Nothing is saved yet.',
    'Select at least one operation to enable confirmation.':
        'Select a change to save.',
    'Selection updated. Review the bound diff before confirming.':
        'Your selection changed. Check it before saving.',
    'No bound Creator operation is selected. Nothing was saved.':
        'No change is selected. Nothing was saved.',
    'Confirmation expired. The preview was refreshed; review it again. Nothing was saved.':
        'This preview expired. Review the updated version. Nothing was saved.',
    'Confirmation binding did not match the displayed diff. Nothing was saved.':
        'The confirmation does not match this preview. Review it again. Nothing was saved.',
    'Creator data changed after this preview. Review the refreshed version before confirming. Nothing was saved.':
        'Your saved items changed. Review the updated preview. Nothing was saved.',
    'Applying only the selected, confirmed operation…':
        'Saving the change you confirmed…',
    'Creator could not finish the confirmed operation. Review the current data before retrying.':
        'We could not finish saving. Check your saved items before trying again.',
    'Saved exactly once from the selected confirmation.': 'Saved.',
    'Undo is bound to another account. The saved item was not changed.':
        'This undo belongs to another account. The saved item was not changed.',
    'The undo window expired. The saved item was not changed.':
        'It is too late to undo this save. The saved item was not changed.',
    'Undo could not complete. The current item state was preserved.':
        'We could not undo this save. The saved item was not changed.',
    'Creation undone. Repeated undo requests will not mutate data again.':
        'Save undone. Repeating this will not change anything else.',
    'Person context changed after this preview. Stage and review a new proposal before confirming. Nothing was saved.':
        'The information you shared changed. Prepare a new preview and review it. Nothing was saved.',
    'This confirmation was already applied. No duplicate items were created.':
        'Already saved. No duplicate items were created.',
    'Creator confirmation requires a verified account boundary. Nothing was saved.':
        'We could not verify your account. Nothing was saved.',
    'Creator confirmation requires a verified account boundary. The saved item was not changed.':
        'We could not verify your account. The saved item was not changed.',
  };

  static const _messages = <String, String>{
    'Review the exact selected change. Nothing has been saved yet.':
        'Revisa el cambio seleccionado. Aún no se ha guardado nada.',
    'Select at least one operation to enable confirmation.':
        'Selecciona al menos una operación para poder confirmar.',
    'Selection updated. Review the bound diff before confirming.':
        'Selección actualizada. Revisa los cambios antes de confirmar.',
    'No bound Creator operation is selected. Nothing was saved.':
        'No se ha seleccionado ningún cambio. No se guardó nada.',
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
