part of 'settings_screen.dart';

class _GlobalMetricsDebugSection extends ConsumerStatefulWidget {
  const _GlobalMetricsDebugSection();

  @override
  ConsumerState<_GlobalMetricsDebugSection> createState() =>
      _GlobalMetricsDebugSectionState();
}

class _GlobalMetricsDebugSectionState
    extends ConsumerState<_GlobalMetricsDebugSection> {
  AsyncValue<OptimizationDebugViewModel> _configAsync =
      const AsyncValue.loading();
  AsyncValue<List<Map<String, dynamic>>> _metricsRealtimeAsync =
      const AsyncValue.loading();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_reloadMetrics());
    });
  }

  void _applyAfterBuild(VoidCallback update) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(update);
    });
  }

  Future<void> _reloadMetrics({bool invalidate = false}) async {
    if (invalidate) {
      ref.invalidate(optimizationDebugViewModelProvider);
      ref.invalidate(supabaseMetricsRealtimeProvider);
    }

    _applyAfterBuild(() {
      _configAsync = const AsyncValue.loading();
      _metricsRealtimeAsync = const AsyncValue.loading();
    });

    try {
      final OptimizationDebugViewModel config = await ref.read(
        optimizationDebugViewModelProvider.future,
      );
      _applyAfterBuild(() {
        _configAsync = AsyncValue<OptimizationDebugViewModel>.data(config);
      });
    } on Object catch (error, stackTrace) {
      _applyAfterBuild(() {
        _configAsync = AsyncValue<OptimizationDebugViewModel>.error(
          error,
          stackTrace,
        );
      });
    }

    try {
      final List<Map<String, dynamic>> rows = await ref
          .read(supabaseMetricsRealtimeProvider.future)
          .timeout(const Duration(seconds: 3));
      _applyAfterBuild(() {
        _metricsRealtimeAsync = AsyncValue<List<Map<String, dynamic>>>.data(
          rows,
        );
      });
    } on Object catch (error, stackTrace) {
      _applyAfterBuild(() {
        _metricsRealtimeAsync = AsyncValue<List<Map<String, dynamic>>>.error(
          error,
          stackTrace,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'GLOBAL OPTIMIZER',
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          _configAsync.when(
            data: (config) => Column(
              children: [
                _NeonStatusTile(
                  title: 'Execution Duration Multiplier',
                  subtitle: config.executionDurationMultiplier.toStringAsFixed(
                    2,
                  ),
                ),
                _NeonStatusTile(
                  title: 'Task Difficulty Scale',
                  subtitle: config.taskDifficultyScale.toStringAsFixed(2),
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => _NeonStatusTile(
              title: 'Optimizer Error',
              subtitle: settingsPublicFailureMessage(
                context,
                e,
                englishFallback:
                    'Optimizer configuration could not be read. Retry.',
                spanishFallback:
                    'No se pudo leer la configuración del optimizador. Inténtalo de nuevo.',
              ),
            ),
          ),
          _metricsRealtimeAsync.when(
            data: (rows) {
              final String latestDate = rows.isEmpty
                  ? 'n/a'
                  : rows.last['date']?.toString() ?? 'unknown';
              return Column(
                children: [
                  _NeonStatusTile(
                    title: 'Realtime Rows',
                    subtitle: '${rows.length} streamed',
                  ),
                  _NeonStatusTile(
                    title: 'Latest Row Date',
                    subtitle: latestDate,
                  ),
                ],
              );
            },
            loading: () => const _NeonStatusTile(
              title: 'Realtime Rows',
              subtitle: 'Connecting to Supabase stream...',
            ),
            error: (error, _) => _NeonStatusTile(
              title: 'Realtime Error',
              subtitle: settingsPublicFailureMessage(
                context,
                error,
                englishFallback:
                    'Aggregate metrics could not be read. Retry when connected.',
                spanishFallback:
                    'No se pudieron leer las métricas agregadas. Inténtalo de nuevo cuando tengas conexión.',
              ),
            ),
          ),
          _NeonNavTile(
            title: 'Refresh Global Metrics',
            subtitle: 'Fetches latest aggregate data from Supabase',
            onTap: () {
              unawaited(_reloadMetrics(invalidate: true));
            },
          ),
        ],
      ),
    );
  }
}

class _SupabaseBackendHealthSection extends ConsumerWidget {
  const _SupabaseBackendHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(supabaseBackendHealthProvider);
    return _Section(
      label: 'SUPABASE BACKEND',
      accentColor: AppColors.memoryAmber,
      child: healthAsync.when(
        data: (health) => Column(
          children: [
            _NeonStatusTile(
              title: 'Status',
              subtitle: health.isHealthy ? 'Healthy' : 'Degraded',
            ),
            _NeonStatusTile(title: 'Health Badge', subtitle: health.badgeLabel),
            _NeonStatusTile(
              title: 'Configured / Initialized',
              subtitle: '${health.configured} / ${health.initialized}',
            ),
            _NeonStatusTile(
              title: 'Authenticated / Realtime',
              subtitle:
                  '${health.authenticated} / ${health.realtimeConfigured}',
            ),
            _NeonStatusTile(
              title: 'Database / Storage',
              subtitle:
                  '${health.databaseReachable} / ${health.storageReachable}',
            ),
            _NeonStatusTile(title: 'Detail', subtitle: health.message),
            _NeonNavTile(
              title: 'Recheck Backend Health',
              subtitle:
                  'Runs diagnostics for Supabase configuration and reachability',
              onTap: () => ref.invalidate(supabaseBackendHealthProvider),
            ),
          ],
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) => _NeonStatusTile(
          title: 'Backend Health Error',
          subtitle: settingsPublicFailureMessage(
            context,
            error,
            englishFallback:
                'Backend health could not be checked. Retry when connected.',
            spanishFallback:
                'No se pudo comprobar el estado del servidor. Inténtalo de nuevo cuando tengas conexión.',
          ),
        ),
      ),
    );
  }
}

class _CloudDataControlSection extends ConsumerWidget {
  const _CloudDataControlSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Env.isLocalMode) {
      return _Section(
        label: journeyText(context, 'YOUR DATA', 'TUS DATOS'),
        accentColor: AppColors.neonCyan,
        child: _NeonStatusTile(
          title: journeyText(
            context,
            'Stored on this device',
            'Guardados en este dispositivo',
          ),
          subtitle: journeyText(
            context,
            'Your local profile and planning data stay on this device. Cloud backup, sync, and account recovery are unavailable. Removing the app or losing this device can permanently lose your data.',
            'Tu perfil local y tus datos de planificación permanecen en este dispositivo. La copia en la nube, la sincronización y la recuperación de la cuenta no están disponibles. Si desinstalas la aplicación o pierdes el dispositivo, podrías perder los datos permanentemente.',
          ),
        ),
      );
    }
    final AsyncValue<bool> syncAsync = ref.watch(cloudSyncPreferenceProvider);
    final bool enabled = syncAsync.asData?.value ?? false;
    final bool available = Env.enableCloudSync;
    return _Section(
      label: journeyText(context, 'YOUR DATA', 'TUS DATOS'),
      accentColor: AppColors.neonCyan,
      child: Column(
        children: [
          _NeonToggleTile(
            title: journeyText(
              context,
              'Cloud Backup',
              'Copia de seguridad en la nube',
            ),
            value: enabled && available,
            onChanged: (bool value) {
              if (!available) return;
              unawaited(
                ref
                    .read(cloudSyncPreferenceProvider.notifier)
                    .setEnabled(value),
              );
            },
          ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Storage scope',
              'Alcance del almacenamiento',
            ),
            subtitle: !available
                ? journeyText(
                    context,
                    'This build is local-only.',
                    'Esta versión funciona solo de forma local.',
                  )
                : enabled
                ? journeyText(
                    context,
                    'Tasks, profile, and settings may be encrypted and synced to your account.',
                    'Las tareas, el perfil y los ajustes pueden cifrarse y sincronizarse con tu cuenta.',
                  )
                : journeyText(
                    context,
                    'Local-only. Nothing is sent to cloud backup.',
                    'Solo local. No se envía nada a la copia de seguridad en la nube.',
                  ),
          ),
          if (available)
            _NeonNavTile(
              title: journeyText(
                context,
                'Backup recovery key',
                'Clave de recuperación de la copia',
              ),
              subtitle: journeyText(
                context,
                'Reveal or restore the key needed on a replacement device.',
                'Muestra o restaura la clave necesaria en un dispositivo de reemplazo.',
              ),
              onTap: () => _showBackupRecoveryKeyDialog(context, ref),
            )
          else
            _NeonStatusTile(
              title: journeyText(
                context,
                'Backup recovery key',
                'Clave de recuperación de la copia',
              ),
              subtitle: journeyText(
                context,
                'Available when cloud backup is enabled for this build.',
                'Disponible cuando la copia en la nube está habilitada para esta versión.',
              ),
            ),
          _NeonStatusTile(
            title: journeyText(
              context,
              'Guidance processing',
              'Procesamiento de la orientación',
            ),
            subtitle: journeyText(
              context,
              'Smart Planner and SI Console explain when a request stays local or uses an opted-in external service.',
              'El Planificador Inteligente y la Consola SI explican cuándo una solicitud permanece local o usa un servicio externo autorizado.',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showBackupRecoveryKeyDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final String? action = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(
        journeyText(
          context,
          'Backup recovery key',
          'Clave de recuperación de respaldo',
        ),
      ),
      content: Text(
        journeyText(
          context,
          'This key lets you decrypt your encrypted cloud backup on a replacement device. Keep it in a password manager. Axiomara cannot recover it for you.',
          'Esta clave permite descifrar tu respaldo cifrado en la nube desde otro dispositivo. Guárdala en un gestor de contraseñas. Axiomara no puede recuperarla por ti.',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(journeyText(context, 'Cancel', 'Cancelar')),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop('import'),
          child: Text(journeyText(context, 'Restore key', 'Restaurar clave')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop('reveal'),
          child: Text(journeyText(context, 'Reveal key', 'Mostrar clave')),
        ),
      ],
    ),
  );
  if (!context.mounted || action == null) {
    return;
  }
  if (action == 'reveal') {
    await _revealBackupRecoveryKey(context, ref);
    return;
  }
  await _importBackupRecoveryKey(context, ref);
}

Future<void> _revealBackupRecoveryKey(
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
              'Reveal recovery key?',
              '¿Mostrar la clave de recuperación?',
            ),
          ),
          content: Text(
            journeyText(
              context,
              'Anyone who sees this key can decrypt your cloud backups. Only continue somewhere private.',
              'Cualquier persona que vea esta clave puede descifrar tus respaldos en la nube. Continúa solo en un lugar privado.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(journeyText(context, 'Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(journeyText(context, 'Reveal', 'Mostrar')),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) {
    return;
  }

  final String key = await ref
      .read(settingsUiActionsProvider)
      .exportBackupRecoveryKey();
  if (!context.mounted) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(
        journeyText(
          context,
          'Store this recovery key',
          'Guarda esta clave de recuperación',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            journeyText(
              context,
              'Copy it to a password manager. Do not share it.',
              'Cópiala en un gestor de contraseñas. No la compartas.',
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            key,
            key: const Key('backup-recovery-key-value'),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: key));
            if (!dialogContext.mounted) {
              return;
            }
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              SnackBar(
                content: Text(
                  journeyText(
                    context,
                    'Recovery key copied.',
                    'Clave de recuperación copiada.',
                  ),
                ),
              ),
            );
          },
          icon: const Icon(Icons.copy_outlined),
          label: Text(journeyText(context, 'Copy', 'Copiar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(journeyText(context, 'Done', 'Listo')),
        ),
      ],
    ),
  );
}

Future<void> _importBackupRecoveryKey(
  BuildContext context,
  WidgetRef ref,
) async {
  final String? recoveryKey = await showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => TextControllerScope(
      builder: (dialogContext, controllers) {
        final controller = controllers[0];
        return AlertDialog(
          title: Text(
            journeyText(
              context,
              'Restore backup key',
              'Restaurar clave de respaldo',
            ),
          ),
          content: TextField(
            key: const Key('backup-recovery-key-input'),
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: journeyText(
                context,
                'Recovery key',
                'Clave de recuperación',
              ),
              hintText: journeyText(
                context,
                'Paste the key from your previous device',
                'Pega la clave de tu dispositivo anterior',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(journeyText(context, 'Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: Text(journeyText(context, 'Continue', 'Continuar')),
            ),
          ],
        );
      },
    ),
  );
  if (!context.mounted || recoveryKey == null || recoveryKey.trim().isEmpty) {
    return;
  }

  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            journeyText(
              context,
              'Replace this device key?',
              '¿Reemplazar la clave de este dispositivo?',
            ),
          ),
          content: Text(
            journeyText(
              context,
              'This replaces this device\'s cloud-backup key. Use the original key again if you need to decrypt backups created with it.',
              'Esto reemplaza la clave de respaldo en la nube de este dispositivo. Vuelve a usar la clave original si necesitas descifrar respaldos creados con ella.',
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
                journeyText(context, 'Replace key', 'Reemplazar clave'),
              ),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) {
    return;
  }

  try {
    await ref
        .read(settingsUiActionsProvider)
        .importBackupRecoveryKey(recoveryKey);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Recovery key saved. You can now restore your backup.',
            'Clave de recuperación guardada. Ya puedes restaurar tu copia de seguridad.',
          ),
        ),
      ),
    );
  } on FormatException {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'That recovery key is not valid.',
            'Esa clave de recuperación no es válida.',
          ),
        ),
      ),
    );
  }
}

class _AdaptiveGuidanceDebugSection extends ConsumerWidget {
  const _AdaptiveGuidanceDebugSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdaptiveGuidanceState> guidance = ref.watch(
      adaptiveGuidanceProvider,
    );
    return _Section(
      label: 'ADAPTIVE GUIDE DIAGNOSTICS',
      accentColor: AppColors.neonViolet,
      child: guidance.when(
        loading: () => const _NeonStatusTile(
          title: 'State',
          subtitle: 'Loading account-scoped milestones...',
        ),
        error: (Object error, StackTrace _) => _NeonStatusTile(
          title: 'State Error',
          subtitle: settingsPublicFailureMessage(
            context,
            error,
            englishFallback:
                'Account-scoped guide state could not be read. Retry.',
            spanishFallback:
                'No se pudo leer el estado de la guía de esta cuenta. Inténtalo de nuevo.',
          ),
        ),
        data: (AdaptiveGuidanceState state) => _NeonStatusTile(
          title: 'Observed progress',
          subtitle:
              'coreComplete=${state.coreComplete} · outcomes=${state.milestones.length} · '
              'skipped=${state.skippedLessons.length} · repeatedDeferral=${state.hasDeferralFriction}',
        ),
      ),
    );
  }
}
