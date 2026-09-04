part of 'settings_screen.dart';

@immutable
final class PersonContextSafetyCopy {
  const PersonContextSafetyCopy({required this.isSpanish});

  factory PersonContextSafetyCopy.of(BuildContext context) =>
      PersonContextSafetyCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  final bool isSpanish;

  String kindLabel(PersonContextKind kind) => switch (kind) {
    PersonContextKind.role => isSpanish ? 'Rol' : 'Role',
    PersonContextKind.value => isSpanish ? 'Valor' : 'Value',
    PersonContextKind.currentPriority =>
      isSpanish ? 'Prioridad actual' : 'Current priority',
    PersonContextKind.lifeArea => isSpanish ? 'Área de vida' : 'Life area',
    PersonContextKind.presentCapacity =>
      isSpanish ? 'Capacidad actual' : 'Capacity right now',
    PersonContextKind.preferredSupportStyle =>
      isSpanish ? 'Estilo de apoyo preferido' : 'Preferred support style',
    PersonContextKind.boundary => isSpanish ? 'Límite' : 'Boundary',
    PersonContextKind.importantRelationship =>
      isSpanish ? 'Relación importante' : 'Important relationship',
    PersonContextKind.commitment => isSpanish ? 'Compromiso' : 'Commitment',
    PersonContextKind.outcomeHistory =>
      isSpanish ? 'Resultado confirmado' : 'Confirmed outcome',
  };

  String surfaceLabel(PersonContextSurface surface) => switch (surface) {
    PersonContextSurface.smartPlanner =>
      isSpanish ? 'Planificador Inteligente' : 'Smart Planner',
    PersonContextSurface.siConsole => isSpanish ? 'Consola SI' : 'SI Console',
    PersonContextSurface.nexus => 'Nexus',
    PersonContextSurface.trajectory => isSpanish ? 'Trayectoria' : 'Trajectory',
    PersonContextSurface.creator => isSpanish ? 'Creador' : 'Creator',
    PersonContextSurface.settings => isSpanish ? 'Ajustes' : 'Settings',
  };

  String purposeLabel(PersonContextPurpose purpose) => switch (purpose) {
    PersonContextPurpose.decisionSupport =>
      isSpanish ? 'apoyo para decisiones' : 'decision support',
    PersonContextPurpose.planningGuidance =>
      isSpanish ? 'guía de planificación' : 'planning guidance',
    PersonContextPurpose.reflection => isSpanish ? 'reflexión' : 'reflection',
    PersonContextPurpose.outcomeLearning =>
      isSpanish ? 'aprendizaje de resultados' : 'outcome learning',
  };

  String get aboutYou => isSpanish ? 'Sobre ti' : 'About you';
  String get rightNow => isSpanish ? 'Ahora mismo' : 'Right now';
  String get addTitle =>
      isSpanish ? 'Añadir contexto personal' : 'Add person context';
  String get exactOnly => isSpanish
      ? 'No se infiere nada. ChronoSpark usará únicamente el texto exacto que decidas guardar.'
      : 'Nothing is inferred. ChronoSpark will use only the exact text you choose to save.';
  String get beforeOptIn => isSpanish
      ? 'Antes de aceptar: el Contexto personal se guarda solo en este dispositivo, se excluye de copias de seguridad y sincronización, y no se restaurará tras reinstalar ChronoSpark o cambiar de dispositivo.'
      : 'Before you opt in: Person Context is stored only on this device, excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.';
  String get storedOnlyHere => isSpanish
      ? 'Se guarda solo en este dispositivo. El Contexto personal se excluye de copias de seguridad y sincronización, y no se restaurará tras reinstalar ChronoSpark o cambiar de dispositivo.'
      : 'Stored only on this device. Person Context is excluded from backup and sync, and will not be restored after reinstalling ChronoSpark or changing devices.';
  String get type => isSpanish ? 'Tipo' : 'Type';
  String get exactTextToRemember =>
      isSpanish ? 'Texto exacto que se recordará' : 'Exact text to remember';
  String get whereMayUse => isSpanish
      ? '¿Dónde puede ChronoSpark usarlo?'
      : 'Where may ChronoSpark use this?';
  String get settingsReviewDisclosure => isSpanish
      ? 'La revisión en Ajustes es administrativa y no requiere consentimiento para influir en el comportamiento.'
      : 'Settings review is administrative and does not require behavioral consent.';
  String freshnessAndExpiry(Duration freshness, Duration expiry) {
    String duration(Duration value) {
      final bool hours = value.inHours <= 24;
      final int amount = hours ? value.inHours : value.inDays;
      if (isSpanish) return '$amount ${hours ? 'horas' : 'días'}';
      return '$amount ${hours ? 'hours' : 'days'}';
    }

    return isSpanish
        ? 'Vigente durante ${duration(freshness)} · caduca después de ${duration(expiry)}'
        : 'Fresh for ${duration(freshness)} · expires after ${duration(expiry)}';
  }

  String get cancel => isSpanish ? 'Cancelar' : 'Cancel';
  String get saveWithConsent =>
      isSpanish ? 'Guardar con consentimiento' : 'Save with consent';
  String get savedWithConsent => isSpanish
      ? 'Contexto personal guardado con consentimiento.'
      : 'Person context saved with consent.';
  String get actionFailed => isSpanish
      ? 'No se pudo completar la acción de Contexto personal. Los datos existentes no cambiaron. Inténtalo de nuevo.'
      : 'The Person Context action could not be completed. Existing data was unchanged. Retry.';
  String get correctTitle =>
      isSpanish ? 'Corregir contexto personal' : 'Correct person context';
  String get exactText => isSpanish ? 'Texto exacto' : 'Exact text';
  String get correctionReason => isSpanish
      ? '¿Por qué lo estás corrigiendo?'
      : 'Why are you correcting it?';
  String get saveCorrection =>
      isSpanish ? 'Guardar corrección' : 'Save correction';
  String get deleteTitle => isSpanish
      ? '¿Eliminar este contexto personal?'
      : 'Delete this person context?';
  String deleteBody(String value) => isSpanish
      ? '“$value” se eliminará permanentemente. Las tareas, objetivos y elementos de la Línea de Tiempo no cambiarán.'
      : '“$value” will be permanently removed. Tasks, goals, and Timeline items are unchanged.';
  String get delete => isSpanish ? 'Eliminar' : 'Delete';
  String get withdrawTitle =>
      isSpanish ? '¿Retirar el consentimiento?' : 'Withdraw consent?';
  String withdrawBody(String value) => isSpanish
      ? 'ChronoSpark dejará de usar “$value” inmediatamente. El registro con fecha seguirá disponible para revisión, exportación, corrección o eliminación.'
      : 'ChronoSpark will immediately stop using “$value”. The timestamped record remains available for review, export, correction, or deletion.';
  String get withdrawConsent =>
      isSpanish ? 'Retirar consentimiento' : 'Withdraw consent';
  String get reviewTitle =>
      isSpanish ? 'Revisar contexto personal' : 'Review person context';
  String get loading => isSpanish
      ? 'Cargando contexto consentido…'
      : 'Loading consented context…';
  String get reviewUnavailable => isSpanish
      ? 'Los datos de contexto recuperables necesitan atención y no están disponibles para revisión.'
      : 'Recoverable context data needs attention and is not available for review.';
  String get accountUnavailable => isSpanish
      ? 'El contexto personal no está disponible para esta cuenta.'
      : 'Person context unavailable';
  String get notProvidedTruth => isSpanish
      ? 'No proporcionado. ChronoSpark no inventará contexto personal.'
      : 'Not provided. ChronoSpark will not invent personal context.';
  String get correct => isSpanish ? 'Corregir' : 'Correct';
  String get done => isSpanish ? 'Hecho' : 'Done';
  String signalDetails(PersonContextSignal signal) {
    final String dateFresh = signal.freshUntil
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    final String dateExpiry = signal.expiresAt
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    final String source = switch (signal.source) {
      PersonContextSource.userAuthored =>
        isSpanish ? 'creado por ti' : 'user authored',
      PersonContextSource.confirmedOutcome =>
        isSpanish ? 'resultado confirmado' : 'confirmed outcome',
    };
    final String consent = switch (signal.consent) {
      PersonContextConsent.granted => isSpanish ? 'otorgado' : 'granted',
      PersonContextConsent.withdrawn => isSpanish ? 'retirado' : 'withdrawn',
    };
    final String export = switch (signal.exportBehavior) {
      PersonContextExportBehavior.include => isSpanish ? 'incluir' : 'include',
      PersonContextExportBehavior.exclude => isSpanish ? 'excluir' : 'exclude',
    };
    final String deletion = switch (signal.deletionBehavior) {
      PersonContextDeletionBehavior.userRemovable =>
        isSpanish ? 'eliminable por ti' : 'user removable',
      PersonContextDeletionBehavior.expiresAutomatically =>
        isSpanish ? 'caduca automáticamente' : 'expires automatically',
      PersonContextDeletionBehavior.deleteWithAccount =>
        isSpanish ? 'eliminar con la cuenta' : 'delete with account',
    };
    final String surfaces = signal.surfaceScopes.map(surfaceLabel).join(', ');
    if (isSpanish) {
      return '${kindLabel(signal.kind)} · $source\n'
          'Propósito: ${purposeLabel(signal.purpose)} · Consentimiento: $consent\n'
          'Áreas: $surfaces\n'
          'Vigente hasta: $dateFresh · Caduca: $dateExpiry\n'
          'Correcciones: ${signal.corrections.length} · Exportación: $export · Eliminación: $deletion';
    }
    return '${kindLabel(signal.kind)} · $source\n'
        'Purpose: ${purposeLabel(signal.purpose)} · Consent: $consent\n'
        'Surfaces: $surfaces\n'
        'Fresh until: $dateFresh · Expires: $dateExpiry\n'
        'Corrections: ${signal.corrections.length} · Export: $export · Deletion: $deletion';
  }

  String get exportCopied => isSpanish
      ? 'Se copió la exportación de Contexto personal.'
      : 'Person context export copied.';
  String get deleteAllTitle => isSpanish
      ? '¿Eliminar todo el contexto personal?'
      : 'Delete all person context?';
  String deleteAllBody(int count) => isSpanish
      ? 'Esto elimina permanentemente $count ${count == 1 ? 'elemento de contexto creado por ti' : 'elementos de contexto creados por ti'}. Las tareas, objetivos y elementos de la Línea de Tiempo no cambiarán.'
      : 'This permanently removes $count user-authored context item${count == 1 ? '' : 's'}. Tasks, goals, and Timeline items are unchanged.';
  String get deleteAll => isSpanish ? 'Eliminar todo' : 'Delete all';
  String get clearCorruptTitle => isSpanish
      ? '¿Borrar permanentemente el Contexto personal dañado?'
      : 'Permanently clear corrupt Person Context?';
  String get clearCorruptBody => isSpanish
      ? 'Esto borra permanentemente solo los datos recuperables o dañados de Contexto personal guardados en este dispositivo. Las tareas, objetivos y elementos de la Línea de Tiempo no se verán afectados. No se puede deshacer.'
      : 'This permanently clears only recoverable or corrupt Person Context payloads stored on this device. Tasks, goals, and Timeline items are unaffected. This cannot be undone.';
  String get permanentlyClear =>
      isSpanish ? 'Borrar permanentemente' : 'Permanently clear';
  String get corruptCleared => isSpanish
      ? 'Se borraron los datos dañados de Contexto personal.'
      : 'Corrupt Person Context data cleared.';
  String get sectionLabel => isSpanish ? 'CONTEXTO PERSONAL' : 'PERSON CONTEXT';
  String get temporarilyUnavailable => isSpanish
      ? 'Contexto personal no disponible temporalmente'
      : 'Person context temporarily unavailable';
  String get transientBody => isSpanish
      ? 'El contexto guardado no cambió ni se trató como vacío. Inténtalo de nuevo cuando la cuenta o el almacenamiento del dispositivo estén listos.'
      : 'Stored context was not changed or treated as empty. Retry after the account or device storage is ready.';
  String get retryContext =>
      isSpanish ? 'Reintentar Contexto personal' : 'Retry person context';
  String get retryBody => isSpanish
      ? 'Intenta una nueva lectura sin eliminar nada.'
      : 'Attempts a fresh read without deleting anything.';
  String get corruptUnavailableBody => isSpanish
      ? 'Los datos de contexto recuperables necesitan atención. No se tratan como vacíos ni se usan para ofrecer guía.'
      : 'Recoverable context data needs attention. It is not being treated as empty or used for guidance.';
  String get clearCorruptNav => isSpanish
      ? 'Borrar datos dañados de Contexto personal'
      : 'Clear corrupt Person Context data';
  String get clearCorruptNavBody => isSpanish
      ? 'Borra permanentemente solo los datos recuperables o dañados de Contexto personal.'
      : 'Permanently clears only recoverable or corrupt Person Context payloads.';
  String get signedInRequired => isSpanish
      ? 'Se requiere una cuenta verificada con sesión iniciada. No se inventará contexto personal.'
      : 'A verified signed-in account is required. No personal context will be invented.';
  String get coauthoredDisclosure => isSpanish
      ? 'Opcional y creado contigo. ChronoSpark usa solo el contexto exacto que guardas, únicamente para los propósitos y áreas que eliges. Lo desconocido permanece desconocido.'
      : 'Optional and co-authored. ChronoSpark uses only the exact context you save, only for the purposes and surfaces you choose. Unknown stays unknown.';
  String get notProvided => isSpanish ? 'No proporcionado' : 'Not provided';
  String itemCount(int count, {required bool freshnessLimited}) {
    if (isSpanish) {
      return freshnessLimited
          ? '$count ${count == 1 ? 'elemento con vigencia limitada' : 'elementos con vigencia limitada'}'
          : '$count ${count == 1 ? 'elemento revisable' : 'elementos revisables'}';
    }
    return freshnessLimited
        ? '$count freshness-limited item${count == 1 ? '' : 's'}'
        : '$count reviewable item${count == 1 ? '' : 's'}';
  }

  String get confirmedOutcomes =>
      isSpanish ? 'Resultados confirmados' : 'Confirmed outcomes';
  String get noOutcomes => isSpanish
      ? 'No se registró historial de resultados'
      : 'No outcome history recorded';
  String outcomeCount(int count) => isSpanish
      ? '$count ${count == 1 ? 'resultado revisable' : 'resultados revisables'}'
      : '$count reviewable outcome${count == 1 ? '' : 's'}';
  String get addNavBody => isSpanish
      ? 'Elige el texto exacto, el propósito, las áreas y la caducidad.'
      : 'Choose exact text, purpose, surfaces, and expiry.';
  String get reviewAndCorrect =>
      isSpanish ? 'Revisar y corregir' : 'Review and correct';
  String get reviewNavBody => isSpanish
      ? 'Revisa el origen, consentimiento, alcance, vigencia, historial y controles.'
      : 'Inspect source, consent, scope, freshness, history, and controls.';
  String get exportContext =>
      isSpanish ? 'Exportar contexto personal' : 'Export person context';
  String get exportNavBody => isSpanish
      ? 'Copia solo los elementos marcados para exportar.'
      : 'Copies only items marked for export.';
  String get deleteAllNav => isSpanish
      ? 'Eliminar todo el contexto personal'
      : 'Delete all person context';
  String deleteAllNavBody(int count) => isSpanish
      ? 'Elimina permanentemente los $count elementos de contexto.'
      : 'Permanently removes all $count context items.';
}

class _PersonContextSection extends ConsumerWidget {
  const _PersonContextSection();

  static const Set<PersonContextKind> _aboutYouKinds = <PersonContextKind>{
    PersonContextKind.role,
    PersonContextKind.value,
    PersonContextKind.lifeArea,
    PersonContextKind.preferredSupportStyle,
    PersonContextKind.boundary,
    PersonContextKind.importantRelationship,
  };

  static const Set<PersonContextKind> _rightNowKinds = <PersonContextKind>{
    PersonContextKind.currentPriority,
    PersonContextKind.presentCapacity,
    PersonContextKind.commitment,
  };

  PersonContextPurpose _purposeFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.role ||
    PersonContextKind.value ||
    PersonContextKind.lifeArea ||
    PersonContextKind.currentPriority ||
    PersonContextKind.presentCapacity ||
    PersonContextKind.commitment => PersonContextPurpose.decisionSupport,
    PersonContextKind.preferredSupportStyle ||
    PersonContextKind.boundary ||
    PersonContextKind.importantRelationship =>
      PersonContextPurpose.planningGuidance,
    PersonContextKind.outcomeHistory => PersonContextPurpose.outcomeLearning,
  };

  Duration _freshnessFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.presentCapacity => const Duration(hours: 24),
    PersonContextKind.currentPriority ||
    PersonContextKind.commitment => const Duration(days: 30),
    PersonContextKind.outcomeHistory => const Duration(days: 90),
    _ => const Duration(days: 180),
  };

  Duration _expiryFor(PersonContextKind kind) => switch (kind) {
    PersonContextKind.presentCapacity => const Duration(hours: 24),
    PersonContextKind.currentPriority ||
    PersonContextKind.commitment => const Duration(days: 90),
    _ => const Duration(days: 366),
  };

  PersonContextDeletionBehavior _deletionFor(PersonContextKind kind) =>
      kind == PersonContextKind.presentCapacity
      ? PersonContextDeletionBehavior.expiresAutomatically
      : PersonContextDeletionBehavior.userRemovable;

  void _showActionFailure(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    Logger.errorCode(
      code: 'settings.person_context_action_failed',
      debugMessage: 'A Person Context action failed.',
      exception: error,
      stackTrace: stackTrace,
    );
    if (!context.mounted) return;
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final PublicFailure failure = PublicFailure.from(
      error,
      fallback: copy.actionFailed,
      isSpanish: copy.isSpanish,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final TextEditingController textController = TextEditingController();
    PersonContextKind kind = PersonContextKind.currentPriority;
    final Set<PersonContextSurface> selected = <PersonContextSurface>{};
    final _PersonContextDraft? draft = await showDialog<_PersonContextDraft>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final String grouping = _aboutYouKinds.contains(kind)
              ? copy.aboutYou
              : copy.rightNow;
          return AlertDialog(
            title: Text(copy.addTitle),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(copy.exactOnly),
                    const SizedBox(height: 8),
                    Text(copy.beforeOptIn),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PersonContextKind>(
                      key: const Key('person-context-kind'),
                      initialValue: kind,
                      decoration: InputDecoration(labelText: copy.type),
                      items:
                          <PersonContextKind>[
                                ..._aboutYouKinds,
                                ..._rightNowKinds,
                              ]
                              .map(
                                (PersonContextKind value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(copy.kindLabel(value)),
                                ),
                              )
                              .toList(growable: false),
                      onChanged: (PersonContextKind? value) {
                        if (value != null) {
                          setState(() {
                            kind = value;
                            selected.retainAll(
                              allowedPersonContextSurfacesFor(
                                _purposeFor(value),
                              ),
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('$grouping · ${copy.purposeLabel(_purposeFor(kind))}'),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('person-context-value'),
                      controller: textController,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: PersonContextSignal.maxValueLength,
                      decoration: InputDecoration(
                        labelText: copy.exactTextToRemember,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(copy.whereMayUse),
                    Text(copy.settingsReviewDisclosure),
                    ...allowedPersonContextSurfacesFor(_purposeFor(kind)).map(
                      (PersonContextSurface surface) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(copy.surfaceLabel(surface)),
                        value: selected.contains(surface),
                        onChanged: (bool? checked) {
                          setState(() {
                            if (checked ?? false) {
                              selected.add(surface);
                            } else {
                              selected.remove(surface);
                            }
                          });
                        },
                      ),
                    ),
                    Text(
                      copy.freshnessAndExpiry(
                        _freshnessFor(kind),
                        _expiryFor(kind),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(copy.cancel),
              ),
              FilledButton(
                key: const Key('person-context-confirm-add'),
                onPressed: () {
                  final String text = textController.text.trim();
                  if (text.isEmpty || selected.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    _PersonContextDraft(
                      kind: kind,
                      value: text,
                      surfaces: selected,
                    ),
                  );
                },
                child: Text(copy.saveWithConsent),
              ),
            ],
          );
        },
      ),
    );
    textController.dispose();
    if (draft == null) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    final int existingCount =
        ref.read(personContextSpineProvider).value?.signals.length ?? 0;
    final PersonContextSignal signal = PersonContextSignal(
      id: '${draft.kind.name}-${now.microsecondsSinceEpoch}-$existingCount',
      kind: draft.kind,
      value: draft.value,
      source: PersonContextSource.userAuthored,
      consent: PersonContextConsent.granted,
      consentedAt: now,
      purpose: _purposeFor(draft.kind),
      surfaceScopes: draft.surfaces,
      recordedAt: now,
      freshUntil: now.add(_freshnessFor(draft.kind)),
      expiresAt: now.add(_expiryFor(draft.kind)),
      exportBehavior: PersonContextExportBehavior.include,
      deletionBehavior: _deletionFor(draft.kind),
    );
    try {
      await ref.read(personContextActionsProvider).upsert(signal);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.savedWithConsent)));
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final TextEditingController valueController = TextEditingController(
      text: signal.value,
    );
    final TextEditingController reasonController = TextEditingController();
    final _PersonContextCorrectionDraft? draft =
        await showDialog<_PersonContextCorrectionDraft>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.correctTitle),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: valueController,
                    maxLength: PersonContextSignal.maxValueLength,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(labelText: copy.exactText),
                  ),
                  TextField(
                    controller: reasonController,
                    maxLength: PersonContextCorrection.maxReasonLength,
                    decoration: InputDecoration(
                      labelText: copy.correctionReason,
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final String value = valueController.text.trim();
                  final String reason = reasonController.text.trim();
                  if (value.isEmpty || reason.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    _PersonContextCorrectionDraft(value: value, reason: reason),
                  );
                },
                child: Text(copy.saveCorrection),
              ),
            ],
          ),
        );
    valueController.dispose();
    reasonController.dispose();
    if (draft == null) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    try {
      await ref
          .read(personContextActionsProvider)
          .correct(
            signalId: signal.id,
            value: draft.value,
            correctedAt: now,
            reason: draft.reason,
            freshUntil: now.add(_freshnessFor(signal.kind)),
            expiresAt: now.add(_expiryFor(signal.kind)),
          );
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.deleteTitle),
            content: Text(copy.deleteBody(signal.value)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(personContextActionsProvider).remove(signal.id);
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    PersonContextSignal signal,
  ) async {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.withdrawTitle),
            content: Text(copy.withdrawBody(signal.value)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.withdrawConsent),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final DateTime now = ref.read(personContextClockProvider)().toUtc();
    try {
      await ref
          .read(personContextActionsProvider)
          .withdrawConsent(signalId: signal.id, withdrawnAt: now);
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  Future<void> _review(BuildContext context) {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final AsyncValue<PersonContextSpine?> spineAsync = ref.watch(
            personContextSpineProvider,
          );
          return AlertDialog(
            title: Text(copy.reviewTitle),
            content: SizedBox(
              width: 620,
              child: spineAsync.when(
                loading: () => Text(copy.loading),
                error: (_, _) => Text(copy.reviewUnavailable),
                data: (PersonContextSpine? spine) {
                  final List<PersonContextSignal>? signals = spine?.signals;
                  if (signals == null) {
                    return Text(copy.accountUnavailable);
                  }
                  if (signals.isEmpty) {
                    return Text(copy.notProvidedTruth);
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: signals.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (BuildContext context, int index) {
                      final PersonContextSignal signal = signals[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(signal.value),
                        subtitle: Text(copy.signalDetails(signal)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (signal.consent == PersonContextConsent.granted)
                              IconButton(
                                tooltip: copy.withdrawConsent,
                                onPressed: () => unawaited(
                                  _withdraw(dialogContext, ref, signal),
                                ),
                                icon: const Icon(Icons.block_outlined),
                              ),
                            IconButton(
                              tooltip: copy.correct,
                              onPressed: () => unawaited(
                                _correct(dialogContext, ref, signal),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: copy.delete,
                              onPressed: () => unawaited(
                                _remove(dialogContext, ref, signal),
                              ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(copy.done),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    try {
      final Map<String, dynamic> export = await ref
          .read(personContextActionsProvider)
          .export();
      await Clipboard.setData(
        ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.exportCopied)));
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    if (count == 0) return;
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.deleteAllTitle),
            content: Text(copy.deleteAllBody(count)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.deleteAll),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(personContextActionsProvider).clear();
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  Future<void> _clearCorruptData(BuildContext context, WidgetRef ref) async {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(copy.clearCorruptTitle),
            content: Text(copy.clearCorruptBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                key: const Key('person-context-confirm-clear-corrupt'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(copy.permanentlyClear),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(personContextActionsProvider).clear();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copy.corruptCleared)));
    } on Object catch (error, stackTrace) {
      if (!context.mounted) return;
      _showActionFailure(context, error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PersonContextSafetyCopy copy = PersonContextSafetyCopy.of(context);
    final AsyncValue<PersonContextSpine?> spineAsync = ref.watch(
      personContextSpineProvider,
    );
    return _Section(
      label: copy.sectionLabel,
      accentColor: AppColors.neonViolet,
      child: spineAsync.when(
        loading: () =>
            _NeonStatusTile(title: copy.reviewTitle, subtitle: copy.loading),
        error: (Object error, _) {
          if (error is PersonContextCorruptionException) {
            return Column(
              children: <Widget>[
                _NeonStatusTile(
                  title: copy.accountUnavailable,
                  subtitle: copy.corruptUnavailableBody,
                ),
                _NeonNavTile(
                  title: copy.clearCorruptNav,
                  subtitle: copy.clearCorruptNavBody,
                  onTap: () => unawaited(_clearCorruptData(context, ref)),
                ),
              ],
            );
          }
          return Column(
            children: <Widget>[
              _NeonStatusTile(
                title: copy.temporarilyUnavailable,
                subtitle: copy.transientBody,
              ),
              _NeonNavTile(
                title: copy.retryContext,
                subtitle: copy.retryBody,
                onTap: () => ref.invalidate(personContextSpineProvider),
              ),
            ],
          );
        },
        data: (PersonContextSpine? spine) {
          if (spine == null) {
            return _NeonStatusTile(
              title: copy.accountUnavailable,
              subtitle: copy.signedInRequired,
            );
          }
          final List<PersonContextSignal> aboutYou = spine.signals
              .where((signal) => _aboutYouKinds.contains(signal.kind))
              .toList(growable: false);
          final List<PersonContextSignal> rightNow = spine.signals
              .where((signal) => _rightNowKinds.contains(signal.kind))
              .toList(growable: false);
          final int outcomes = spine.signals
              .where(
                (signal) => signal.kind == PersonContextKind.outcomeHistory,
              )
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  copy.coauthoredDisclosure,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  copy.storedOnlyHere,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              _NeonStatusTile(
                title: copy.aboutYou,
                subtitle: aboutYou.isEmpty
                    ? copy.notProvided
                    : copy.itemCount(aboutYou.length, freshnessLimited: false),
              ),
              _NeonStatusTile(
                title: copy.rightNow,
                subtitle: rightNow.isEmpty
                    ? copy.notProvided
                    : copy.itemCount(rightNow.length, freshnessLimited: true),
              ),
              _NeonStatusTile(
                title: copy.confirmedOutcomes,
                subtitle: outcomes == 0
                    ? copy.noOutcomes
                    : copy.outcomeCount(outcomes),
              ),
              _NeonNavTile(
                title: copy.addTitle,
                subtitle: copy.addNavBody,
                onTap: () => unawaited(_add(context, ref)),
              ),
              _NeonNavTile(
                title: copy.reviewAndCorrect,
                subtitle: copy.reviewNavBody,
                onTap: () => unawaited(_review(context)),
              ),
              _NeonNavTile(
                title: copy.exportContext,
                subtitle: copy.exportNavBody,
                onTap: () => unawaited(_export(context, ref)),
              ),
              _NeonNavTile(
                title: copy.deleteAllNav,
                subtitle: copy.deleteAllNavBody(spine.signals.length),
                onTap: () =>
                    unawaited(_deleteAll(context, ref, spine.signals.length)),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _PersonContextDraft {
  const _PersonContextDraft({
    required this.kind,
    required this.value,
    required this.surfaces,
  });

  final PersonContextKind kind;
  final String value;
  final Set<PersonContextSurface> surfaces;
}

final class _PersonContextCorrectionDraft {
  const _PersonContextCorrectionDraft({
    required this.value,
    required this.reason,
  });

  final String value;
  final String reason;
}
