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
          if (available)
            _NeonStatusTile(
              subtitleMaxLines: null,
              title: journeyText(
                context,
                'Recovery coverage',
                'Alcance de la recuperación',
              ),
              subtitle: journeyText(
                context,
                'Choose Back up all planning data to save an encrypted snapshot of tasks, goals, habits, notes, outcome and Schedule history, profile and settings. Keep your recovery key separately. Older and automatic backups may only include tasks, profile and settings. Private memories and personal information shared for guidance remain on this device.',
                'Elige Guardar todos los datos para crear una copia cifrada de tareas, metas, hábitos, notas, historial de resultados y cronología, perfil y ajustes. Guarda la clave de recuperación por separado. Las copias anteriores y automáticas pueden incluir solo tareas, perfil y ajustes. Las memorias privadas y la información personal compartida para orientación permanecen en este dispositivo.',
              ),
            ),
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
          if (available && enabled)
            _NeonStatusTile(
              title: CloudBackupStatusCopy.of(context).lastBackupTitle,
              subtitle: CloudBackupStatusCopy.of(context).lastBackupValue(
                _formatBackupTime(
                  context,
                  ref.watch(lastCloudBackupProvider).asData?.value,
                ),
              ),
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
            CloudBackupActions(
              key: ValueKey(ref.watch(accountStorageScopeProvider).v2Namespace),
              enabled: enabled,
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
              'Choose a step and Chat explain when a request uses this device or an external service you have allowed.',
              'Elegir un paso y Chat explican cuándo una solicitud permanece local o usa un servicio externo autorizado.',
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

  final String? key = await ref
      .read(settingsUiActionsProvider)
      .exportBackupRecoveryKey();
  if (!context.mounted) {
    return;
  }
  if (key == null) {
    final BackupRecoveryKeyCopy copy = BackupRecoveryKeyCopy.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(copy.noKeyTitle),
        content: Text(copy.noKeyBody),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(journeyText(context, 'Done', 'Listo')),
          ),
        ],
      ),
    );
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

  // The key is tested against the current cloud backup before it replaces
  // the stored key; a key that does not open it changes nothing.
  final RecoveryKeyImportOutcome outcome = await ref.read(
    backupRecoveryKeyImportProvider,
  )(recoveryKey);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(BackupRecoveryKeyCopy.of(context).importOutcome(outcome)),
    ),
  );
}

/// Bilingual copy for the "Last backup" line next to the Cloud Backup toggle.
final class CloudBackupStatusCopy {
  const CloudBackupStatusCopy({required this.isSpanish});

  final bool isSpanish;

  static CloudBackupStatusCopy of(BuildContext context) =>
      CloudBackupStatusCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  String _text(String english, String spanish) => isSpanish ? spanish : english;

  String get lastBackupTitle =>
      _text('Last backup', 'Última copia de seguridad');

  /// [formattedTime] is the backup date and time in the reader's locale, or
  /// null when this device has no record of a backup.
  String lastBackupValue(String? formattedTime) =>
      formattedTime ??
      _text(
        'No backup recorded on this device yet.',
        'Este dispositivo aún no tiene registrada ninguna copia.',
      );
}

String? _formatBackupTime(BuildContext context, DateTime? at) {
  if (at == null) return null;
  final DateTime local = at.toLocal();
  final MaterialLocalizations formats = MaterialLocalizations.of(context);
  return '${formats.formatMediumDate(local)} · '
      '${formats.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// Bilingual copy for the backup recovery key flows.
final class BackupRecoveryKeyCopy {
  const BackupRecoveryKeyCopy({required this.isSpanish});

  final bool isSpanish;

  static BackupRecoveryKeyCopy of(BuildContext context) =>
      BackupRecoveryKeyCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  String _text(String english, String spanish) => isSpanish ? spanish : english;

  String get noKeyTitle => _text(
    'No backup key on this device yet',
    'Todavía no hay una clave de respaldo en este dispositivo',
  );

  String get noKeyBody => _text(
    'If you backed up on another device, choose Restore key and paste the recovery key you saved there. Otherwise this device makes its key the first time it backs up.',
    'Si hiciste una copia en otro dispositivo, elige Restaurar clave y pega la clave de recuperación que guardaste allí. Si no, este dispositivo creará su clave la primera vez que haga una copia.',
  );

  String importOutcome(RecoveryKeyImportOutcome outcome) => switch (outcome) {
    RecoveryKeyImportOutcome.installed => _text(
      'Recovery key saved. It opens your cloud backup, so you can restore it now.',
      'Clave de recuperación guardada. Abre tu copia en la nube, así que ya puedes restaurarla.',
    ),
    RecoveryKeyImportOutcome.installedUnverified => _text(
      'Recovery key saved. There is no cloud backup to check it against yet, so your previous key is kept until a backup opens.',
      'Clave de recuperación guardada. Aún no hay una copia en la nube para comprobarla, así que tu clave anterior se conserva hasta que se abra una copia.',
    ),
    RecoveryKeyImportOutcome.doesNotMatch => _text(
      'This key does not match your cloud backup. Your current key was not changed.',
      'Esta clave no coincide con tu copia en la nube. Tu clave actual no se cambió.',
    ),
    RecoveryKeyImportOutcome.invalidFormat => _text(
      'That recovery key is not valid.',
      'Esa clave de recuperación no es válida.',
    ),
    RecoveryKeyImportOutcome.cloudUnavailable => _text(
      'Could not check this key against your cloud backup. Your current key was not changed. Turn on Cloud Backup, check your connection, and try again.',
      'No se pudo comprobar esta clave con tu copia en la nube. Tu clave actual no se cambió. Activa la copia en la nube, revisa tu conexión e inténtalo de nuevo.',
    ),
    RecoveryKeyImportOutcome.accountChanged => _text(
      'Your account changed before the key could be checked. Your current key was not changed.',
      'Tu cuenta cambió antes de poder comprobar la clave. Tu clave actual no se cambió.',
    ),
  };
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
