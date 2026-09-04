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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Memory receipts copied.')));
  }

  Future<void> _correct(
    BuildContext context,
    WidgetRef ref,
    MemoryEntity memory,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: memory.text,
    );
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Correct remembered preference'),
        content: TextField(
          key: const Key('memory-correction-field'),
          controller: controller,
          maxLength: 280,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            helperText: 'Only this exact preference text will be replaced.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) return;
    try {
      await ref
          .read(memoryGovernanceControllerProvider)
          .correctPreference(id: memory.id, text: next);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preference corrected.')));
    } on Object catch (error, stackTrace) {
      Logger.errorCode(
        code: 'settings.memory_correction_failed',
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
            title: const Text('Delete this memory?'),
            content: Text(
              '“${memory.text}” will be permanently removed and cannot be retrieved again.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
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
            title: const Text('Memory receipts'),
            content: SizedBox(
              width: 560,
              child: memories.isEmpty
                  ? const Text(
                      'No durable memories. “Use only this time” remains the default.',
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
                                tooltip: 'Correct',
                                onPressed: () => unawaited(
                                  _correct(dialogContext, ref, memory),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
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
                child: const Text('Done'),
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
    if (count == 0) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete all durable memories?'),
            content: Text(
              'This permanently removes $count consented memory receipt${count == 1 ? '' : 's'}. Tasks, goals, and Timeline data are unchanged.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete all'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(memoryGovernanceControllerProvider).deleteAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All durable memories deleted.')),
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
            title: const Text('Clear short-lived assistant context?'),
            content: const Text(
              'This clears short-lived Smart Planner and SI Console context. It does not delete tasks, goals, Timeline data, or governed memory receipts.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Clear context'),
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
      const SnackBar(content: Text('Short-lived assistant context cleared.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MemoryEntity> memories = ref.watch(memoriesProvider);
    return _Section(
      label: 'MEMORY GOVERNANCE',
      accentColor: AppColors.memoryAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Use only this time is the default. Durable memory requires an explicit confirmation, stays in the source surface, expires automatically, and always creates a receipt. Raw emotional and crisis disclosures are not retained. SI durable interpretive memory is disabled.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _NeonStatusTile(
            title: 'Active memory receipts',
            subtitle:
                '${memories.length} · account-scoped · surface-scoped · expiring',
          ),
          const _NeonStatusTile(
            title: 'SI Console durable memory',
            subtitle:
                'Disabled — SI cannot save or retrieve interpretive memory.',
          ),
          _NeonNavTile(
            title: 'Review memory receipts',
            subtitle: 'View exact text, purpose, source, expiry, and controls.',
            onTap: () => unawaited(_reviewReceipts(context)),
          ),
          _NeonNavTile(
            title: 'Export memory receipts',
            subtitle: 'Copies governed receipts only — never raw transcripts.',
            onTap: () => unawaited(_exportReceipts(context, ref)),
          ),
          _NeonNavTile(
            title: 'Delete all durable memories',
            subtitle:
                'Permanently removes all ${memories.length} active receipts.',
            onTap: () => unawaited(_deleteAll(context, ref, memories.length)),
          ),
          _NeonNavTile(
            title: 'Clear short-lived assistant context',
            subtitle: 'Clears surface-local context separately.',
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
  });

  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  item.toString().split('.').last,
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
    return _Section(
      label: 'ASSISTANT RELEASE CONTROL',
      accentColor: AppColors.neonViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'New assistant behavior is assigned deterministically. Joining beta is optional; leaving removes beta eligibility. Planner, SI, memory, critic, and optional external explanation each have an independent emergency rollback.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          _NeonToggleTile(
            title: 'Join opt-in assistant beta',
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
            title: 'Release stage',
            subtitle: loadedConfig == null
                ? 'Loading fail-closed release configuration...'
                : loadedConfig.configurationValid
                ? loadedConfig.stage.name
                : 'Disabled: ${loadedConfig.configurationIssue}',
          ),
          _NeonStatusTile(
            title: 'Your Planner cohort',
            subtitle: plannerDecision.when(
              data: (AssistantReleaseDecision decision) =>
                  '${decision.cohort.name} · ${decision.enabled ? 'enabled' : 'not enabled'}',
              loading: () => 'Resolving without exposing account identity...',
              error: (Object _, StackTrace _) =>
                  'Disabled because release state could not be verified.',
            ),
          ),
          _NeonStatusTile(
            title: 'Privacy-safe shadow evaluation',
            subtitle: loadedConfig?.shadowEvaluationEnabled == true
                ? 'Enabled for digests and finding codes only; cannot publish or write.'
                : 'Disabled',
          ),
          for (final AssistantReleaseCapability capability
              in AssistantReleaseCapability.values)
            _NeonStatusTile(
              title: _assistantCapabilityLabel(capability),
              subtitle: loadedConfig?.isRolledBack(capability) == true
                  ? 'Emergency rollback active'
                  : 'Independent rollback ready',
            ),
        ],
      ),
    );
  }
}

String _assistantCapabilityLabel(AssistantReleaseCapability capability) {
  return switch (capability) {
    AssistantReleaseCapability.smartPlannerV2 => 'Smart Planner V2',
    AssistantReleaseCapability.siConsoleV2 => 'SI Console V2',
    AssistantReleaseCapability.governedMemory => 'Governed memory',
    AssistantReleaseCapability.safetyCritic => 'Safety critic',
    AssistantReleaseCapability.plannerExplanation =>
      'Optional Planner explanation',
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
      label: 'ADAPTIVE GUIDE',
      accentColor: AppColors.memoryAmber,
      child: guidance.when(
        loading: () => const _NeonStatusTile(
          title: 'Loading guide',
          subtitle: 'Reading account-scoped progress...',
        ),
        error: (Object error, StackTrace _) => _NeonStatusTile(
          title: 'Guide unavailable',
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
                    ? 'Contextual guidance active'
                    : 'Learning the core workflow',
                subtitle:
                    '${state.milestones.length} real outcomes observed · '
                    '${state.skippedLessons.length} prompts muted',
              ),
              _NeonNavTile(
                title: 'Restart Adaptive Guide',
                subtitle:
                    'Keeps real outcomes and reopens the next relevant contextual intervention.',
                onTap: () => unawaited(_restartGuide(context, ref)),
              ),
              _NeonNavTile(
                title: 'Restart first setup',
                subtitle:
                    'Reopens welcome and account setup. Keeps tasks, milestones, and Adaptive Guide progress.',
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
        const SnackBar(content: Text('Adaptive guide restarted.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adaptive guide could not restart.')),
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
        const SnackBar(content: Text('First setup could not restart.')),
      );
    }
  }
}
