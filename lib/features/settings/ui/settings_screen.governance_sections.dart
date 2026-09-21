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
                      'Stored durable memory is unreadable. This permanently removes the unreadable account-scoped payload. Tasks, goals, and Timeline data are unchanged.',
                      'La memoria duradera guardada no puede leerse. Esto elimina permanentemente los datos ilegibles de esta cuenta. Las tareas, metas y datos de Línea de Tiempo no cambian.',
                    )
                  : journeyText(
                      context,
                      'This permanently removes $count consented memory receipt${count == 1 ? '' : 's'}. Tasks, goals, and Timeline data are unchanged.',
                      'Esto elimina permanentemente $count ${count == 1 ? 'registro de memoria autorizado' : 'registros de memoria autorizados'}. Las tareas, metas y datos de Línea de Tiempo no cambian.',
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
                'This clears short-lived Smart Planner and SI Console context. It does not delete tasks, goals, Timeline data, or governed memory receipts.',
                'Esto borra el contexto temporal del Planificador Inteligente y la Consola SI. No elimina tareas, metas, datos de Línea de Tiempo ni registros de memoria controlados.',
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
    ref.invalidate(siEngineStateProvider);
    ref.invalidate(smartPlannerEngineStateProvider);
    ref.invalidate(siMemoryProvider);
    ref.invalidate(smartPlannerMemoryProvider);
    ref.invalidate(aiResponseProvider);
    ref.invalidate(smartPlannerAiResponseProvider);
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
      label: journeyText(context, 'MEMORY GOVERNANCE', 'CONTROL DE LA MEMORIA'),
      accentColor: AppColors.memoryAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              journeyText(
                context,
                'Use only this time is the default. Durable memory requires an explicit confirmation, stays in the source surface, expires automatically, and always creates a receipt. Raw emotional and crisis disclosures are not retained. SI durable interpretive memory is disabled.',
                'Usar solo esta vez es la opción predeterminada. La memoria duradera requiere una confirmación explícita, permanece en su área de origen, caduca automáticamente y siempre crea un registro. No se conservan expresiones emocionales ni de crisis sin procesar. La memoria interpretativa duradera de SI está desactivada.',
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
                    '${memories.length} · account-scoped · surface-scoped · expiring',
                    '${memories.length} · limitados a la cuenta · limitados al área · con caducidad',
                  ),
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'SI Console durable memory',
              'Memoria duradera de la Consola SI',
            ),
            subtitle: journeyText(
              context,
              'Disabled — SI cannot save or retrieve interpretive memory.',
              'Desactivada: SI no puede guardar ni recuperar memoria interpretativa.',
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
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T value)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownRouteKeyboardGuard(
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF0B111C),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.neonCyan.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
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
          onChanged: (T? next) {
            if (next != null) onChanged(next);
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
    return _Section(
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
                'New assistant behavior is assigned deterministically. Joining beta is optional; leaving removes beta eligibility. Planner, SI, memory, critic, and optional external explanation each have an independent emergency rollback.',
                'El comportamiento nuevo del asistente se asigna de forma determinista. Unirse a la beta es opcional; salir elimina la elegibilidad. El Planificador, SI, la memoria, el crítico y la explicación externa opcional tienen cada uno una reversión de emergencia independiente.',
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
              'Your Planner cohort',
              'Tu cohorte del Planificador',
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
    );
  }
}

String _assistantCapabilityLabel(
  AssistantReleaseCapability capability, {
  required bool isSpanish,
}) {
  return switch (capability) {
    AssistantReleaseCapability.smartPlannerV2 => 'Smart Planner V2',
    AssistantReleaseCapability.siConsoleV2 => 'SI Console V2',
    AssistantReleaseCapability.governedMemory =>
      isSpanish ? 'Memoria controlada' : 'Governed memory',
    AssistantReleaseCapability.safetyCritic =>
      isSpanish ? 'Crítico de seguridad' : 'Safety critic',
    AssistantReleaseCapability.plannerExplanation =>
      isSpanish
          ? 'Explicación opcional del Planificador'
          : 'Optional Planner explanation',
  };
}

class _AdaptiveGuidanceSection extends ConsumerWidget {
  const _AdaptiveGuidanceSection();

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
            'Reading account-scoped progress...',
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
                title: state.coreComplete
                    ? journeyText(
                        context,
                        'Contextual guidance active',
                        'Orientación contextual activa',
                      )
                    : journeyText(
                        context,
                        'Learning the core workflow',
                        'Aprendiendo el flujo principal',
                      ),
                subtitle: journeyText(
                  context,
                  '${state.milestones.length} real outcomes observed · ${state.skippedLessons.length} prompts muted',
                  '${state.milestones.length} resultados reales observados · ${state.skippedLessons.length} avisos silenciados',
                ),
              ),
              _NeonNavTile(
                title: journeyText(
                  context,
                  'Restart Adaptive Guide',
                  'Reiniciar la Guía Adaptativa',
                ),
                subtitle: journeyText(
                  context,
                  'Keeps real outcomes and reopens the next relevant contextual intervention.',
                  'Conserva los resultados reales y vuelve a abrir la siguiente intervención contextual pertinente.',
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
                  'Reopens welcome and account setup. Keeps tasks, milestones, and Adaptive Guide progress.',
                  'Vuelve a abrir la bienvenida y la configuración de la cuenta. Conserva las tareas, los hitos y el progreso de la Guía Adaptativa.',
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
