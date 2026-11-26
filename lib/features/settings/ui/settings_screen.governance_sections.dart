part of 'settings_screen.dart';

class _MemoryGovernanceSection extends ConsumerWidget {
  const _MemoryGovernanceSection();

  String _date(DateTime? value) {
    if (value == null) return 'Not set';
    return value.toLocal().toIso8601String().split('T').first;
  }

  Future<void> _exportReceipts(BuildContext context, WidgetRef ref) async {
    final Map<String, dynamic> export = ref
        .read(memoryGovernanceControllerProvider)
        .exportReceipts();
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(export)),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Memory receipts copied.',
            'Comprobantes de memoria copiados.',
          ),
        ),
      ),
    );
  }

  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    MemoryEntity memory,
  ) async {
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => TextControllerScope(
        initialTexts: <String>[memory.text],
        builder: (dialogContext, controllers) {
          final controller = controllers[0];
          return AlertDialog(
            title: Text(
              journeyText(
                context,
                'Correct remembered preference',
                'Corregir preferencia recordada',
              ),
            ),
            content: TextField(
              key: const Key('memory-correction-field'),
              controller: controller,
              maxLength: 280,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                helperText: journeyText(
                  context,
                  'Only this exact preference text will be replaced.',
                  'Solo se reemplazará el texto exacto de esta preferencia.',
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(journeyText(context, 'Cancel', 'Cancelar')),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: Text(
                  journeyText(context, 'Save correction', 'Guardar corrección'),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (next == null) return;
    try {
      await ref
          .read(memoryGovernanceControllerProvider)
          .correctPreference(id: memory.id, text: next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journeyText(
              context,
              'Preference corrected.',
              'Preferencia corregida.',
            ),
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      Logger.errorCode(
        code: AppDiagnosticCode.settingsMemoryCorrectionFailed,
        debugMessage: 'Memory correction failed.',
        exception: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settingsPublicFailureMessage(
              context,
              error,
              englishFallback:
                  'The preference could not be corrected. Existing memory was unchanged. Retry.',
              spanishFallback:
                  'No se pudo corregir la preferencia. La memoria existente no cambió. Inténtalo de nuevo.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    MemoryEntity memory,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(
              journeyText(
                context,
                'Delete this memory?',
                '¿Eliminar este recuerdo?',
              ),
            ),
            content: Text(
              journeyText(
                context,
                '“${memory.text}” will be permanently removed and cannot be retrieved again.',
                '“${memory.text}” se eliminará permanentemente y no se podrá recuperar.',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(journeyText(context, 'Cancel', 'Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(journeyText(context, 'Delete', 'Eliminar')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(memoryGovernanceControllerProvider).deleteMemory(memory.id);
  }

  Future<void> _reviewReceipts(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          final List<MemoryEntity> memories = ref.watch(memoriesProvider);
          return AlertDialog(
            title: Text(
              journeyText(context, 'Memory receipts', 'Registros de memoria'),
            ),
            content: SizedBox(
              width: 560,
              child: memories.isEmpty
                  ? Text(
                      journeyText(
                        context,
                        'No durable memories. “Use only this time” remains the default.',
                        'No hay recuerdos duraderos. “Usar solo esta vez” sigue siendo la opción predeterminada.',
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: memories.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (BuildContext context, int index) {
                        final MemoryEntity memory = memories[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(memory.text),
                          subtitle: Text(
                            'Why: ${memory.whyStored}\n'
                            'Source: ${memory.sourceSurface.label} · Expires: ${_date(memory.expiresAt)}\n'
                            'Consent: ${memory.consentStatus.name} · Controls: view, correct, export, delete',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: journeyText(
                                  context,
                                  'Correct',
                                  'Corregir',
                                ),
                                onPressed: () => unawaited(
                                  _correct(dialogContext, ref, memory),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: journeyText(
                                  context,
                                  'Delete',
                                  'Eliminar',
                                ),
                                onPressed: () => unawaited(
                                  _deleteOne(dialogContext, ref, memory),
                                ),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(journeyText(context, 'Done', 'Listo')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final bool unreadable = ref.read(memoryReadCorruptedProvider);
    if (count == 0 && !unreadable) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(
              journeyText(
                context,
                'Delete all durable memories?',
                '¿Eliminar todos los recuerdos duraderos?',
              ),
            ),
            content: Text(
              unreadable
                  ? journeyText(
                      context,
                      'Stored durable memory is unreadable. This permanently removes the unreadable account-scoped payload. Tasks, goals, and Schedule data are unchanged.',
                      'La memoria duradera guardada no puede leerse. Esto elimina permanentemente los datos ilegibles de esta cuenta. Las tareas, metas y datos de agenda no cambian.',
                    )
                  : journeyText(
                      context,
                      'This permanently removes $count consented memory receipt${count == 1 ? '' : 's'}. Tasks, goals, and Schedule data are unchanged.',
                      'Esto elimina permanentemente $count ${count == 1 ? 'registro de memoria autorizado' : 'registros de memoria autorizados'}. Las tareas, metas y datos de agenda no cambian.',
                    ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(journeyText(context, 'Cancel', 'Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  journeyText(context, 'Delete all', 'Eliminar todo'),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(memoryGovernanceControllerProvider).deleteAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'All durable memories deleted.',
            'Se eliminaron todos los recuerdos duraderos.',
          ),
        ),
      ),
    );
  }

  Future<void> _clearAssistantContext(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(
              journeyText(
                context,
                'Clear short-lived assistant context?',
                '¿Borrar el contexto temporal del asistente?',
              ),
            ),
            content: Text(
              journeyText(
                context,
                'This clears short-lived assistant planning context. Saved Chat conversations are separate: open Chat and choose Clear conversation to delete that history. This does not delete tasks, goals, Schedule data, or governed memory receipts.',
                'Esto borra el contexto temporal de planificación del asistente. Las conversaciones guardadas de Chat son independientes: abre Chat y elige Borrar conversación para eliminar ese historial. No elimina tareas, metas, datos de agenda ni registros de memoria controlados.',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(journeyText(context, 'Cancel', 'Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  journeyText(context, 'Clear context', 'Borrar contexto'),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(siEngineServiceProvider).clearAllMemory();
    ref.invalidate(siMemoryProvider);
    ref.invalidate(smartPlannerMemoryProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Short-lived assistant context cleared.',
            'Se borró el contexto temporal del asistente.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MemoryEntity> memories = ref.watch(memoriesProvider);
    final bool unreadable = ref.watch(memoryReadCorruptedProvider);
    return _Section(
      label: journeyText(
        context,
        'WHAT AXIOMARA REMEMBERS',
        'LO QUE AXIOMARA RECUERDA',
      ),
      accentColor: AppColors.memoryAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              journeyText(
                context,
                'By default Axiomara uses what you tell it only this once. It keeps something longer only if you confirm it, only for the part of the app it came from, and forgets it automatically after a while. Every kept item has a record you can review. Chat never saves memories. Its conversation history is saved on this device for your account and is separate: open Chat and choose Clear conversation to delete it. Raw emotional and crisis messages are not kept, and interpretive memory is not saved.',
                'De forma predeterminada, Axiomara usa lo que le cuentas solo esta vez. Guarda algo por más tiempo solo si lo confirmas, solo para la parte de la app de donde vino, y lo olvida automáticamente pasado un tiempo. Cada elemento guardado tiene un registro que puedes revisar. Chat nunca guarda memorias. Su historial de conversación se guarda en este dispositivo para tu cuenta y es independiente: abre Chat y elige Borrar conversación para eliminarlo. No se conservan mensajes emocionales ni de crisis sin procesar, y no se guarda memoria interpretativa.',
              ),
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Active memory receipts',
              'Registros de memoria activos',
            ),
            subtitle: unreadable
                ? journeyText(
                    context,
                    'Unreadable retained data detected · review or delete it',
                    'Se detectaron datos conservados ilegibles · revísalos o elimínalos',
                  )
                : journeyText(
                    context,
                    memories.length == 1
                        ? '1 kept · only for your account, only where it was made, and it expires'
                        : '${memories.length} kept · only for your account, only where they were made, and they expire',
                    memories.length == 1
                        ? '1 guardado · solo de tu cuenta, solo donde se creó, y caduca'
                        : '${memories.length} guardados · solo de tu cuenta, solo donde se crearon, y caducan',
                  ),
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Saved conversation preferences',
              'Preferencias de conversación guardadas',
            ),
            subtitle: journeyText(
              context,
              'Off: Chat cannot save or retrieve interpretive memory.',
              'Desactivada: Chat no puede guardar ni recuperar memoria interpretativa.',
            ),
          ),
          _NeonNavTile(
            title: journeyText(
              context,
              'Review memory receipts',
              'Revisar registros de memoria',
            ),
            subtitle: journeyText(
              context,
              'View exact text, purpose, source, expiry, and controls.',
              'Consulta el texto exacto, el propósito, el origen, la caducidad y los controles.',
            ),
            onTap: () => unawaited(_reviewReceipts(context)),
          ),
          _NeonNavTile(
            title: journeyText(
              context,
              'Export memory receipts',
              'Exportar registros de memoria',
            ),
            subtitle: journeyText(
              context,
              'Copies governed receipts only — never raw transcripts.',
              'Copia solo los registros controlados, nunca transcripciones sin procesar.',
            ),
            onTap: () => unawaited(_exportReceipts(context, ref)),
          ),
          _NeonNavTile(
            title: journeyText(
              context,
              'Delete all durable memories',
              'Eliminar todas las memorias duraderas',
            ),
            subtitle: unreadable
                ? journeyText(
                    context,
                    'Permanently removes the unreadable account-scoped payload.',
                    'Elimina permanentemente los datos ilegibles de esta cuenta.',
                  )
                : journeyText(
                    context,
                    'Permanently removes all ${memories.length} active receipts.',
                    'Elimina permanentemente los ${memories.length} registros activos.',
                  ),
            onTap: () => unawaited(_deleteAll(context, ref, memories.length)),
          ),
          _NeonNavTile(
            title: journeyText(
              context,
              'Clear short-lived assistant context',
              'Borrar el contexto temporal del asistente',
            ),
            subtitle: journeyText(
              context,
              'Clears surface-local context separately.',
              'Borra por separado el contexto temporal de cada área.',
            ),
            onTap: () => unawaited(_clearAssistantContext(context, ref)),
          ),
        ],
      ),
    );
  }
}

class _PreferenceDropdown<T> extends StatelessWidget {
  const _PreferenceDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final T value;
  final List<T> items;

  /// Null shows the choice without letting it change.
  final ValueChanged<T>? onChanged;
  final String Function(T value)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownRouteKeyboardGuard(
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: Theme.of(context).colorScheme.surface,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
          ),
          decoration: InputDecoration(labelText: label),
          items: items
              .map(
                (T item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    itemLabel?.call(item) ?? item.toString().split('.').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged == null
              ? null
              : (T? next) {
                  if (next != null) onChanged!(next);
                },
        ),
      ),
    );
  }
}

class _AssistantReleaseSection extends ConsumerWidget {
  const _AssistantReleaseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> optIn = ref.watch(assistantBetaOptInProvider);
    final AsyncValue<AssistantReleaseConfig> config = ref.watch(
      assistantReleaseConfigProvider,
    );
    final AsyncValue<AssistantReleaseDecision> plannerDecision = ref.watch(
      assistantReleaseDecisionProvider(
        AssistantReleaseCapability.smartPlannerV2,
      ),
    );
    final AssistantReleaseConfig? loadedConfig = config.asData?.value;
    final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
    // Release engineering controls are for the internal cohort only: the
    // trusted internal-access flag or an account digest on the internal list
    // (checked on the config so a rollback or an "off" stage does not hide
    // the status view from testers). Everyone else sees nothing, except an
    // account that is still opted in, which sees one switch to leave.
    final bool advisorAccess = ref.watch(internalAdvisorAccessProvider);
    // Show nothing until the opt-in value, the config and the decision have
    // all resolved, so an internal tester never sees the leave-only section
    // flash before the internal list is checked.
    if (!advisorAccess &&
        !(optIn.hasValue && config.hasValue && plannerDecision.hasValue)) {
      return const SizedBox.shrink();
    }
    final String? digest = plannerDecision.asData?.value.accountDigest;
    final bool isInternal =
        advisorAccess ||
        (loadedConfig != null &&
            digest != null &&
            loadedConfig.internalAccountDigests.contains(digest));
    if (!isInternal) {
      if (optIn.asData?.value != true) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _Section(
          label: journeyText(context, 'ASSISTANT BETA', 'BETA DEL ASISTENTE'),
          accentColor: AppColors.neonViolet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  journeyText(
                    context,
                    'Leaving takes your account out of the assistant beta. Some assistant features that were only open to beta members may turn off. Your saved plans are not changed.',
                    'Salir saca tu cuenta de la beta del asistente. Algunas funciones del asistente que eran solo para miembros de la beta pueden desactivarse. Tus planes guardados no cambian.',
                  ),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              _NeonToggleTile(
                title: journeyText(
                  context,
                  'Leave the assistant beta',
                  'Salir de la beta del asistente',
                ),
                value: false,
                onChanged: (bool _) => unawaited(
                  ref
                      .read(assistantBetaOptInProvider.notifier)
                      .setEnabled(false),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _Section(
        label: journeyText(
          context,
          'ASSISTANT RELEASE CONTROL',
          'CONTROL DE VERSIÓN DEL ASISTENTE',
        ),
        accentColor: AppColors.neonViolet,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                journeyText(
                  context,
                  'New assistant behavior is assigned deterministically. Leaving the beta removes beta eligibility. Local planning, the Assistant, memory, critic, and optional AI chat explanation each have an independent emergency rollback.',
                  'El comportamiento nuevo del asistente se asigna de forma determinista. Salir de la beta elimina la elegibilidad. La planificación local, el asistente, la memoria, el crítico y la explicación opcional del chat con IA tienen cada uno una reversión de emergencia independiente.',
                ),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            _NeonToggleTile(
              title: journeyText(
                context,
                'Join opt-in assistant beta',
                'Unirse voluntariamente a la beta del asistente',
              ),
              value: optIn.asData?.value ?? false,
              onChanged: optIn.isLoading
                  ? null
                  : (bool value) => unawaited(
                      ref
                          .read(assistantBetaOptInProvider.notifier)
                          .setEnabled(value),
                    ),
            ),
            _NeonStatusTile(
              title: journeyText(
                context,
                'Release stage',
                'Etapa de lanzamiento',
              ),
              subtitle: loadedConfig == null
                  ? journeyText(
                      context,
                      'Loading fail-closed release configuration...',
                      'Cargando una configuración de lanzamiento segura por defecto...',
                    )
                  : loadedConfig.configurationValid
                  ? loadedConfig.stage.name
                  : journeyText(
                      context,
                      'Disabled: ${loadedConfig.configurationIssue}',
                      'Desactivada: ${loadedConfig.configurationIssue}',
                    ),
            ),
            _NeonStatusTile(
              title: journeyText(
                context,
                'Your local planning rollout group',
                'Tu grupo de activación de planificación local',
              ),
              subtitle: plannerDecision.when(
                data: (AssistantReleaseDecision decision) =>
                    '${decision.cohort.name} · ${decision.enabled ? (isSpanish ? 'habilitada' : 'enabled') : (isSpanish ? 'no habilitada' : 'not enabled')}',
                loading: () => journeyText(
                  context,
                  'Resolving without exposing account identity...',
                  'Resolviendo sin exponer la identidad de la cuenta...',
                ),
                error: (Object _, StackTrace _) => journeyText(
                  context,
                  'Disabled because release state could not be verified.',
                  'Desactivada porque no se pudo verificar el estado del lanzamiento.',
                ),
              ),
            ),
            _NeonStatusTile(
              title: journeyText(
                context,
                'Privacy-safe shadow evaluation',
                'Evaluación paralela con privacidad',
              ),
              subtitle: loadedConfig?.shadowEvaluationEnabled == true
                  ? journeyText(
                      context,
                      'Enabled for digests and finding codes only; cannot publish or write.',
                      'Habilitada solo para resúmenes y códigos de hallazgos; no puede publicar ni escribir.',
                    )
                  : journeyText(context, 'Disabled', 'Desactivada'),
            ),
            for (final AssistantReleaseCapability capability
                in AssistantReleaseCapability.values)
              _NeonStatusTile(
                title: _assistantCapabilityLabel(
                  capability,
                  isSpanish: isSpanish,
                ),
                subtitle: loadedConfig?.isRolledBack(capability) == true
                    ? journeyText(
                        context,
                        'Emergency rollback active',
                        'Reversión de emergencia activa',
                      )
                    : journeyText(
                        context,
                        'Independent rollback ready',
                        'Reversión independiente lista',
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

String _assistantCapabilityLabel(
  AssistantReleaseCapability capability, {
  required bool isSpanish,
}) {
  return switch (capability) {
    AssistantReleaseCapability.smartPlannerV2 => 'Local planning',
    AssistantReleaseCapability.siConsoleV2 => 'Local questions',
    AssistantReleaseCapability.governedMemory =>
      isSpanish ? 'Memoria controlada' : 'Governed memory',
    AssistantReleaseCapability.safetyCritic =>
      isSpanish ? 'Crítico de seguridad' : 'Safety critic',
    AssistantReleaseCapability.plannerExplanation =>
      isSpanish
          ? 'Explicación opcional de planificación'
          : 'Optional planning explanation',
  };
}

/// Recorded guide milestones, for example "1 action recorded".
String _actionsRecorded(BuildContext context, int count) => journeyText(
  context,
  count == 1 ? '1 action recorded' : '$count actions recorded',
  count == 1 ? '1 acción registrada' : '$count acciones registradas',
);

/// Help cards dismissed with "Not now", for example "1 help card hidden".
String _helpCardsHidden(BuildContext context, int count) => journeyText(
  context,
  count == 1 ? '1 help card hidden' : '$count help cards hidden',
  count == 1 ? '1 tarjeta de ayuda oculta' : '$count tarjetas de ayuda ocultas',
);

@visibleForTesting
class AdaptiveGuidanceSettingsSection extends ConsumerWidget {
  const AdaptiveGuidanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdaptiveGuidanceState> guidance = ref.watch(
      adaptiveGuidanceProvider,
    );
    return _Section(
      label: journeyText(context, 'ADAPTIVE GUIDE', 'GUÍA ADAPTATIVA'),
      accentColor: AppColors.memoryAmber,
      child: guidance.when(
        loading: () => _NeonStatusTile(
          title: journeyText(context, 'Loading guide', 'Cargando la guía'),
          subtitle: journeyText(
            context,
            'Reading this account\'s progress...',
            'Leyendo el progreso de esta cuenta...',
          ),
        ),
        error: (Object error, StackTrace _) => _NeonStatusTile(
          title: journeyText(
            context,
            'Guide unavailable',
            'Guía no disponible',
          ),
          subtitle: settingsPublicFailureMessage(
            context,
            error,
            englishFallback:
                'Guide progress could not be read. Existing progress was unchanged. Retry.',
            spanishFallback:
                'No se pudo leer el progreso de la guía. El progreso existente no cambió. Inténtalo de nuevo.',
          ),
        ),
        data: (AdaptiveGuidanceState state) {
          return Column(
            children: <Widget>[
              _NeonStatusTile(
                title: switch (state.coreGuideStatus) {
                  CoreGuideStatus.skipped => journeyText(
                    context,
                    'Guide skipped',
                    'Guía omitida',
                  ),
                  CoreGuideStatus.paused => journeyText(
                    context,
                    'Guide paused',
                    'Guía en pausa',
                  ),
                  _ =>
                    state.coreComplete
                        ? journeyText(
                            context,
                            'Guide finished',
                            'Guía terminada',
                          )
                        : journeyText(
                            context,
                            'Guide in progress',
                            'Guía en curso',
                          ),
                },
                subtitle: switch (state.coreGuideStatus) {
                  CoreGuideStatus.skipped || CoreGuideStatus.paused =>
                    '${_actionsRecorded(context, state.recordedActionCount)} · '
                        '${journeyText(context, 'Restart the guide below to continue.', 'Reinicia la guía abajo para continuar.')}',
                  _ =>
                    '${_actionsRecorded(context, state.recordedActionCount)} · '
                        '${_helpCardsHidden(context, state.skippedLessons.length)}',
                },
              ),
              _NeonNavTile(
                title: journeyText(
                  context,
                  'Restart Adaptive Guide',
                  'Reiniciar la Guía Adaptativa',
                ),
                subtitle: journeyText(
                  context,
                  'Shows the guide again without changing your saved work or activity.',
                  'Vuelve a mostrar la guía sin cambiar tu trabajo ni tu actividad guardados.',
                ),
                onTap: () => unawaited(_restartGuide(context, ref)),
              ),
              _NeonNavTile(
                title: journeyText(
                  context,
                  'Restart first setup',
                  'Reiniciar la configuración inicial',
                ),
                subtitle: journeyText(
                  context,
                  'Reopens welcome and account setup. Keeps your saved work and guide progress.',
                  'Vuelve a abrir la bienvenida y la configuración de la cuenta. Conserva tu trabajo guardado y el progreso de la guía.',
                ),
                onTap: () => unawaited(_restartFirstSetup(context, ref)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restartGuide(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(adaptiveGuidanceProvider.notifier).restartLessons();
      if (!context.mounted) {
        return;
      }
      context.go(ref.read(routeSurfaceProvider).nexus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journeyText(
              context,
              'Adaptive guide restarted.',
              'Guía adaptativa reiniciada.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journeyText(
              context,
              'Adaptive guide could not restart.',
              'No se pudo reiniciar la guía adaptativa.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _restartFirstSetup(BuildContext context, WidgetRef ref) async {
    try {
      await restartFirstSetup(context, ref);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            journeyText(
              context,
              'First setup could not restart.',
              'No se pudo reiniciar la configuración inicial.',
            ),
          ),
        ),
      );
    }
  }
}
