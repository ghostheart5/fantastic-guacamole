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
              subtitle: CloudBackupStatusCopy.of(context).recoveryCoverage,
            ),
          CloudBackupToggle(available: available),
          if (available && enabled)
            _NeonStatusTile(
              subtitleMaxLines: null,
              title: CloudBackupStatusCopy.of(context).lastBackupTitle,
              subtitle: CloudBackupStatusCopy.of(context).lastBackupValue(
                _formatBackupTime(
                  context,
                  ref.watch(lastCloudBackupProvider).asData?.value,
                ),
                attention: ref.watch(cloudBackupAttentionProvider),
              ),
            ),
          if (available && enabled) const CloudBackupKeyStatus(),
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
                ? CloudBackupStatusCopy.of(context).storageScopeOn
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
              beforeFullBackup: () =>
                  _recoveryKeySavedBeforeBackup(context, ref),
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
  await _showRecoveryKeyDialog(context, key, askSaved: false);
}

/// The one place a recovery key is displayed. With [askSaved] the user must
/// confirm they saved it; returns true only then.
Future<bool> _showRecoveryKeyDialog(
  BuildContext context,
  String key, {
  required bool askSaved,
}) async {
  final BackupRecoveryKeyCopy copy = BackupRecoveryKeyCopy.of(context);
  final bool? saved = await showDialog<bool>(
    context: context,
    barrierDismissible: !askSaved,
    builder: (BuildContext dialogContext) => AlertDialog(
      scrollable: true,
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
          label: Text(copy.copyAction),
        ),
        if (askSaved)
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(journeyText(context, 'Cancel', 'Cancelar')),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            askSaved ? copy.savedIt : journeyText(context, 'Done', 'Listo'),
          ),
        ),
      ],
    ),
  );
  return askSaved && saved == true;
}

/// Asks for a recovery key saved elsewhere. Null when cancelled or empty.
Future<String?> _askForSavedRecoveryKey(BuildContext context) async {
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
  if (recoveryKey == null || recoveryKey.trim().isEmpty) return null;
  return recoveryKey;
}

Future<void> _importBackupRecoveryKey(
  BuildContext context,
  WidgetRef ref,
) async {
  final String? recoveryKey = await _askForSavedRecoveryKey(context);
  if (!context.mounted || recoveryKey == null) {
    return;
  }

  final BackupRecoveryKeyCopy copy = BackupRecoveryKeyCopy.of(context);
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(copy.checkKeyTitle),
          content: Text(copy.checkKeyBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(journeyText(context, 'Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.checkKeyAction),
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
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(copy.importOutcome(outcome))));
}

enum _RecoveryKeyStepResult {
  /// The key was shown and the user confirmed they saved it.
  saved,

  /// The user restored a key they had saved elsewhere.
  restored,
  cancelled,
}

/// Whether the signed-in account is still the one a dialog flow started
/// with.
bool Function() _accountLease(WidgetRef ref) {
  final String? namespace = ref.read(accountStorageScopeProvider).v2Namespace;
  final int generation = ref.read(authSessionBoundaryProvider).generation;
  return () =>
      ref.read(accountStorageScopeProvider).v2Namespace == namespace &&
      ref.read(authSessionBoundaryProvider).generation == generation;
}

/// Makes saving the recovery key part of turning on Cloud Backup (and of a
/// first full backup). Shows this device's key with a copy action and asks
/// for an explicit "I have saved it". A device without a key either restores
/// one saved elsewhere or, only when the user asks and the account has no
/// encrypted cloud backup, creates a new one. With [turningOn], Cloud Backup
/// is switched on only at the end, after the key is saved or accepted.
Future<_RecoveryKeyStepResult> _runRecoveryKeyStep(
  BuildContext context,
  WidgetRef ref, {
  required bool turningOn,
}) async {
  final bool Function() sameAccount = _accountLease(ref);
  final BackupRecoveryKeyCopy copy = BackupRecoveryKeyCopy.of(context);
  final SettingsUiActions actions = ref.read(settingsUiActionsProvider);
  String? key = await actions.exportBackupRecoveryKey();
  if (!context.mounted || !sameAccount()) {
    return _RecoveryKeyStepResult.cancelled;
  }
  if (key == null) {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(copy.noKeyTitle),
        content: Text(copy.noKeyChoiceBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(journeyText(context, 'Cancel', 'Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('create'),
            child: Text(copy.createNewKey),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('restore'),
            child: Text(copy.useSavedKey),
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null || !sameAccount()) {
      return _RecoveryKeyStepResult.cancelled;
    }
    if (choice == 'create') {
      // A new key could never open a backup made with another key, so look
      // first (read-only) and refuse when one exists or cannot be checked.
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      CloudBackupPresence presence;
      try {
        presence = await ref.read(cloudBackupPresenceProvider)();
      } on Object {
        presence = CloudBackupPresence.unknown;
      }
      if (!context.mounted || !sameAccount()) {
        return _RecoveryKeyStepResult.cancelled;
      }
      if (presence == CloudBackupPresence.unknown) {
        messenger.showSnackBar(
          SnackBar(content: Text(copy.cannotCheckForBackup)),
        );
        return _RecoveryKeyStepResult.cancelled;
      }
      if (presence == CloudBackupPresence.encryptedBackup) {
        final bool useSaved =
            await showDialog<bool>(
              context: context,
              builder: (BuildContext dialogContext) => AlertDialog(
                scrollable: true,
                title: Text(copy.backupExistsTitle),
                content: Text(copy.backupExistsBody),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(journeyText(context, 'Cancel', 'Cancelar')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(copy.useSavedKey),
                  ),
                ],
              ),
            ) ??
            false;
        if (!useSaved || !context.mounted || !sameAccount()) {
          return _RecoveryKeyStepResult.cancelled;
        }
        return _restoreSavedKeyStep(
          context,
          ref,
          turningOn: turningOn,
          sameAccount: sameAccount,
        );
      }
    } else {
      return _restoreSavedKeyStep(
        context,
        ref,
        turningOn: turningOn,
        sameAccount: sameAccount,
      );
    }
    key = await actions.createBackupRecoveryKey();
    if (!context.mounted || !sameAccount()) {
      return _RecoveryKeyStepResult.cancelled;
    }
  }
  final bool show =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(copy.saveKeyFirstTitle),
          content: Text(copy.saveKeyFirstBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(journeyText(context, 'Cancel', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.showKey),
            ),
          ],
        ),
      ) ??
      false;
  if (!show || !context.mounted || !sameAccount()) {
    return _RecoveryKeyStepResult.cancelled;
  }
  final bool saved = await _showRecoveryKeyDialog(context, key, askSaved: true);
  if (!saved || !sameAccount()) return _RecoveryKeyStepResult.cancelled;
  await ref.read(recoveryKeySavedProvider.notifier).markSaved();
  if (!sameAccount()) return _RecoveryKeyStepResult.cancelled;
  if (turningOn) {
    await ref.read(cloudSyncPreferenceProvider.notifier).setEnabled(true);
  }
  return _RecoveryKeyStepResult.saved;
}

/// Restores a key saved on another device. The key is checked against the
/// cloud backup without turning Cloud Backup on; it is turned on only after
/// the key was accepted and recorded as saved. Any failure leaves it off.
Future<_RecoveryKeyStepResult> _restoreSavedKeyStep(
  BuildContext context,
  WidgetRef ref, {
  required bool turningOn,
  required bool Function() sameAccount,
}) async {
  final String? recoveryKey = await _askForSavedRecoveryKey(context);
  if (!context.mounted || recoveryKey == null || !sameAccount()) {
    return _RecoveryKeyStepResult.cancelled;
  }
  final BackupRecoveryKeyCopy copy = BackupRecoveryKeyCopy.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final CloudSyncPreferenceNotifier preference = ref.read(
    cloudSyncPreferenceProvider.notifier,
  );
  RecoveryKeyImportOutcome outcome;
  try {
    outcome = await ref.read(recoveryKeyRestoreBeforeEnablingProvider)(
      recoveryKey,
    );
  } on Object {
    outcome = RecoveryKeyImportOutcome.cloudUnavailable;
  }
  final bool restored =
      outcome == RecoveryKeyImportOutcome.installed ||
      outcome == RecoveryKeyImportOutcome.installedUnverified;
  messenger.showSnackBar(SnackBar(content: Text(copy.importOutcome(outcome))));
  if (!restored || !sameAccount()) return _RecoveryKeyStepResult.cancelled;
  if (turningOn) await preference.setEnabled(true);
  return _RecoveryKeyStepResult.restored;
}

/// Before a full backup: true when the key is already confirmed as saved,
/// or the user confirms it now. A key restored at this point does not go on
/// to back up: the user should restore the cloud backup first.
Future<bool> _recoveryKeySavedBeforeBackup(
  BuildContext context,
  WidgetRef ref,
) async {
  if (await ref.read(recoveryKeySavedProvider.future)) return true;
  if (!context.mounted) return false;
  return await _runRecoveryKeyStep(context, ref, turningOn: false) ==
      _RecoveryKeyStepResult.saved;
}

/// The Cloud Backup switch. Turning it on for the first time on an account
/// goes through the recovery key step; cancelling leaves it off.
class CloudBackupToggle extends ConsumerWidget {
  const CloudBackupToggle({super.key, required this.available});

  final bool available;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool enabled =
        ref.watch(cloudSyncPreferenceProvider).asData?.value ?? false;
    return _NeonToggleTile(
      title: journeyText(
        context,
        'Cloud Backup',
        'Copia de seguridad en la nube',
      ),
      value: enabled && available,
      onChanged: (bool value) {
        if (!available) return;
        unawaited(_setCloudBackup(context, ref, value));
      },
    );
  }

  Future<void> _setCloudBackup(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final CloudSyncPreferenceNotifier preference = ref.read(
      cloudSyncPreferenceProvider.notifier,
    );
    if (!value) {
      await preference.setEnabled(false);
      return;
    }
    final bool Function() sameAccount = _accountLease(ref);
    final bool saved = await ref.read(recoveryKeySavedProvider.future);
    if (!sameAccount()) return;
    if (saved) {
      await preference.setEnabled(true);
      return;
    }
    if (!context.mounted) return;
    await _runRecoveryKeyStep(context, ref, turningOn: true);
  }
}

/// Status line next to the Cloud Backup switch: whether this device holds a
/// recovery key and whether it opens the current cloud backup. When it
/// cannot, offers discarding the cloud backup behind two confirmations.
class CloudBackupKeyStatus extends ConsumerWidget {
  const CloudBackupKeyStatus({super.key});

  /// Discard is offered only when the cloud backup exists and this device
  /// cannot read it.
  static bool offersDiscard(CloudBackupKeyCheck check) => switch (check) {
    CloudBackupKeyCheck.doesNotMatch ||
    CloudBackupKeyCheck.unreadable ||
    CloudBackupKeyCheck.malformed => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CloudBackupKeyStatusCopy copy = CloudBackupKeyStatusCopy.of(context);
    final AsyncValue<CloudBackupKeyCheck?> status = ref.watch(
      cloudBackupKeyStatusProvider,
    );
    // Until the confirmation has loaded, do not nag.
    final bool keySaved =
        ref.watch(recoveryKeySavedProvider).asData?.value ?? true;
    final CloudBackupKeyCheck? check = status.hasError
        ? CloudBackupKeyCheck.unavailable
        : status.asData?.value;
    if (check == null && !status.isLoading) return const SizedBox.shrink();
    final String text = check == null
        ? copy.checking
        : copy.status(check, keySaved: keySaved);
    final bool offerSaving =
        check != null &&
        !keySaved &&
        check != CloudBackupKeyCheck.noKeyOnDevice;
    final Widget line = _NeonStatusTile(
      title: copy.title,
      subtitle: text,
      subtitleMaxLines: null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (offerSaving)
          SmartPressable(
            semanticLabel: '${copy.title}. $text',
            onTap: () =>
                unawaited(_runRecoveryKeyStep(context, ref, turningOn: false)),
            child: line,
          )
        else
          line,
        if (check != null && offersDiscard(check))
          _NeonNavTile(
            title: CloudBackupDiscardCopy.of(context).actionTitle,
            subtitle: CloudBackupDiscardCopy.of(context).actionSubtitle,
            onTap: () => unawaited(_discardCloudBackup(context, ref)),
          ),
      ],
    );
  }
}

/// Two deliberate steps: an explanation that names the safer choice, then a
/// typed confirmation word. Only then is the discard requested.
Future<void> _discardCloudBackup(BuildContext context, WidgetRef ref) async {
  final bool Function() sameAccount = _accountLease(ref);
  final CloudBackupDiscardCopy copy = CloudBackupDiscardCopy.of(context);
  final bool understood =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(copy.firstStepTitle),
          content: Text(copy.firstStepBody),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(journeyText(context, 'Cancel', 'Cancelar')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(copy.continueAction),
            ),
          ],
        ),
      ) ??
      false;
  if (!understood || !context.mounted || !sameAccount()) return;
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => TextControllerScope(
          builder: (dialogContext, controllers) {
            final TextEditingController controller = controllers[0];
            return AlertDialog(
              scrollable: true,
              title: Text(copy.secondStepTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(copy.secondStepBody),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('discard-cloud-backup-confirmation'),
                    controller: controller,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(journeyText(context, 'Cancel', 'Cancelar')),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, TextEditingValue value, _) => FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.onError,
                    ),
                    onPressed: copy.isConfirmation(value.text)
                        ? () => Navigator.of(dialogContext).pop(true)
                        : null,
                    child: Text(copy.deleteAction),
                  ),
                ),
              ],
            );
          },
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted || !sameAccount()) return;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final CloudBackupDiscardOutcome outcome = await ref.read(
    cloudBackupDiscardProvider,
  )();
  messenger.showSnackBar(SnackBar(content: Text(copy.outcome(outcome))));
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

  /// What a backup includes, before and after the first full backup.
  String get recoveryCoverage => _text(
    'Choose Back up all planning data to save an encrypted snapshot of tasks, goals, habits, notes, outcome and Schedule history, profile and settings. Keep your recovery key separately. Older backups, and automatic backups made before your first full backup, include only tasks, profile and settings. After a full backup, automatic backups keep all of it up to date. Private memories and personal information shared for guidance remain on this device.',
    'Elige Guardar todos los datos para crear una copia cifrada de tareas, metas, hábitos, notas, historial de resultados y cronología, perfil y ajustes. Guarda la clave de recuperación por separado. Las copias anteriores, y las automáticas hechas antes de tu primera copia completa, incluyen solo tareas, perfil y ajustes. Después de una copia completa, las copias automáticas lo mantienen todo al día. Las memorias privadas y la información personal compartida para orientación permanecen en este dispositivo.',
  );

  /// Storage scope while Cloud Backup is on.
  String get storageScopeOn => _text(
    'Encrypted backups go to your account: tasks, profile and settings until you make a full backup, then all planning data.',
    'Las copias cifradas se guardan en tu cuenta: tareas, perfil y ajustes hasta que hagas una copia completa, y después todos los datos de planificación.',
  );

  /// [formattedTime] is the backup date and time in the reader's locale, or
  /// null when this device has no record of a backup. [attention] comes from
  /// the last automatic sync.
  String lastBackupValue(
    String? formattedTime, {
    CloudBackupAttention attention = CloudBackupAttention.none,
  }) {
    final String? note = switch (attention) {
      CloudBackupAttention.none => null,
      CloudBackupAttention.fullBackupNotLinked => _text(
        'A full backup is in the cloud, but this device did not make it. Press Back up all planning data once to keep it up to date automatically. If you use several devices, restore first: that button replaces the cloud copy with this device\'s data.',
        'Hay una copia completa en la nube, pero no la hizo este dispositivo. Pulsa Guardar todos los datos una vez para mantenerla al día automáticamente. Si usas varios dispositivos, restaura primero: ese botón reemplaza la copia en la nube con los datos de este dispositivo.',
      ),
      CloudBackupAttention.changedOnAnotherDevice => _text(
        'Your cloud backup changed on another device, so nothing was uploaded from here. To get those changes, choose Restore cloud backup. Back up all planning data would replace the other device\'s newer copy with this device\'s data.',
        'Tu copia en la nube cambió en otro dispositivo, así que no se subió nada desde aquí. Para obtener esos cambios, elige Restaurar copia en la nube. Guardar todos los datos reemplazaría la copia más reciente del otro dispositivo con los datos de este.',
      ),
    };
    if (formattedTime == null && note == null) {
      return _text(
        'This device has not made or restored a cloud backup yet.',
        'Este dispositivo todavía no ha hecho ni restaurado una copia en la nube.',
      );
    }
    return <String?>[
      if (formattedTime != null) '$formattedTime.',
      note,
    ].whereType<String>().join(' ');
  }
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
    'If you backed up on another device, choose Restore key and paste the recovery key you saved there. Otherwise this device\'s key is created and shown when you turn on Cloud Backup.',
    'Si hiciste una copia en otro dispositivo, elige Restaurar clave y pega la clave de recuperación que guardaste allí. Si no, la clave de este dispositivo se crea y se muestra cuando activas la copia en la nube.',
  );

  String get noKeyChoiceBody => _text(
    'If you backed up on another device, choose Use my saved key and paste the recovery key you saved there. Create a new key only if this account has never been backed up: a new key cannot open an older backup.',
    'Si hiciste una copia en otro dispositivo, elige Usar mi clave guardada y pega la clave de recuperación que guardaste allí. Crea una clave nueva solo si esta cuenta nunca tuvo copia: una clave nueva no puede abrir una copia anterior.',
  );

  String get useSavedKey => _text('Use my saved key', 'Usar mi clave guardada');

  String get createNewKey => _text('Create a new key', 'Crear una clave nueva');

  String get saveKeyFirstTitle => _text(
    'Save your recovery key first',
    'Primero guarda tu clave de recuperación',
  );

  String get saveKeyFirstBody => _text(
    'Your cloud backup is encrypted with a recovery key that stays on this device. You need it to restore on a new or reset phone, and Axiomara cannot recover it for you. Anyone who sees the key can open your backups, so only continue somewhere private.',
    'Tu copia en la nube se cifra con una clave de recuperación que se queda en este dispositivo. La necesitas para restaurar en un teléfono nuevo o restablecido, y Axiomara no puede recuperarla por ti. Cualquier persona que vea la clave puede abrir tus copias, así que continúa solo en un lugar privado.',
  );

  String get showKey => _text('Show key', 'Mostrar clave');

  String get copyAction => _text('Copy', 'Copiar');

  String get savedIt => _text('I have saved it', 'Ya la guardé');

  String get checkKeyTitle =>
      _text('Check this key?', '¿Comprobar esta clave?');

  String get checkKeyBody => _text(
    'Axiomara first checks the key against your cloud backup. It becomes this device\'s key only if it opens the backup, or if there is no backup yet; then your current key is kept as a fallback. If it does not open the backup, nothing changes.',
    'Axiomara primero comprueba la clave con tu copia en la nube. Se convierte en la clave de este dispositivo solo si abre la copia, o si aún no hay copia; en ese caso, tu clave actual se conserva como respaldo. Si no abre la copia, no cambia nada.',
  );

  String get backupExistsTitle => _text(
    'This account already has a cloud backup',
    'Esta cuenta ya tiene una copia en la nube',
  );

  String get backupExistsBody => _text(
    'Only the recovery key it was made with can open it, and a new key never could. Choose Use my saved key and paste the key you saved on the device that made it. No new key was created.',
    'Solo la clave de recuperación con la que se hizo puede abrirla, y una clave nueva nunca podría. Elige Usar mi clave guardada y pega la clave que guardaste en el dispositivo que la hizo. No se creó ninguna clave nueva.',
  );

  String get cannotCheckForBackup => _text(
    'Could not check whether this account already has a cloud backup, so no new key was created. Try again when you are online.',
    'No se pudo comprobar si esta cuenta ya tiene una copia en la nube, así que no se creó ninguna clave nueva. Inténtalo de nuevo cuando tengas conexión.',
  );

  String get checkKeyAction =>
      _text('Check and use key', 'Comprobar y usar clave');

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
    RecoveryKeyImportOutcome.backupUnreadable => _text(
      'This key opens your cloud backup, but the backup is damaged and cannot be restored. Your current key was not changed.',
      'Esta clave abre tu copia en la nube, pero la copia está dañada y no se puede restaurar. Tu clave actual no se cambió.',
    ),
    RecoveryKeyImportOutcome.newerVersion => _text(
      'Your cloud backup was made by a newer version of Axiomara. Update the app on this device, then try again. Your current key was not changed.',
      'Tu copia en la nube la hizo una versión más nueva de Axiomara. Actualiza la aplicación en este dispositivo y vuelve a intentarlo. Tu clave actual no se cambió.',
    ),
    RecoveryKeyImportOutcome.cloudUnavailable => _text(
      'Could not reach your cloud backup to check this key. Get online and try again. Your current key was not changed.',
      'No se pudo conectar con tu copia en la nube para comprobar esta clave. Conéctate a internet e inténtalo de nuevo. Tu clave actual no se cambió.',
    ),
    RecoveryKeyImportOutcome.cloudBackupOff => _text(
      'Turn on Cloud Backup first, then restore your key. Your current key was not changed.',
      'Primero activa la copia en la nube y luego restaura tu clave. Tu clave actual no se cambió.',
    ),
    RecoveryKeyImportOutcome.ownerMismatch => _text(
      'The account signed in to the cloud is not the one this device is using, so the key was not checked. Sign out, sign in again, and try again. Your current key was not changed.',
      'La cuenta conectada a la nube no es la que usa este dispositivo, así que la clave no se comprobó. Cierra sesión, vuelve a iniciarla e inténtalo de nuevo. Tu clave actual no se cambió.',
    ),
    RecoveryKeyImportOutcome.accountChanged => _text(
      'Your account changed before the key could be checked. Your current key was not changed.',
      'Tu cuenta cambió antes de poder comprobar la clave. Tu clave actual no se cambió.',
    ),
  };
}

/// Bilingual copy for the recovery key status line next to Cloud Backup.
final class CloudBackupKeyStatusCopy {
  const CloudBackupKeyStatusCopy({required this.isSpanish});

  final bool isSpanish;

  static CloudBackupKeyStatusCopy of(BuildContext context) =>
      CloudBackupKeyStatusCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  String _text(String english, String spanish) => isSpanish ? spanish : english;

  String get title => _text('Recovery key', 'Clave de recuperación');

  String get checking => _text(
    'Checking whether this device can open your cloud backup…',
    'Comprobando si este dispositivo puede abrir tu copia en la nube…',
  );

  String get notConfirmedNote => _text(
    'You have not confirmed that you saved this key. Tap to save it now.',
    'No has confirmado que guardaste esta clave. Toca para guardarla ahora.',
  );

  /// [keySaved] false adds a reminder when the device has a key the user has
  /// not confirmed saving.
  String status(CloudBackupKeyCheck check, {bool keySaved = true}) {
    final String line = switch (check) {
      CloudBackupKeyCheck.matches => _text(
        'This device has the key, and it opens your cloud backup.',
        'Este dispositivo tiene la clave y abre tu copia en la nube.',
      ),
      CloudBackupKeyCheck.noEncryptedCloudBackup => _text(
        'This device has a key. There is no cloud backup yet to check it against.',
        'Este dispositivo tiene una clave. Todavía no hay una copia en la nube con la que comprobarla.',
      ),
      CloudBackupKeyCheck.noKeyOnDevice => _text(
        'This device has no recovery key. To open a backup made on another device, choose Backup recovery key, then Restore key.',
        'Este dispositivo no tiene clave de recuperación. Para abrir una copia hecha en otro dispositivo, elige Clave de recuperación de la copia y luego Restaurar clave.',
      ),
      CloudBackupKeyCheck.doesNotMatch => _text(
        'This device\'s key does not open your cloud backup, so nothing is backed up from here. Restore the key you saved with Backup recovery key. If that key is lost, you can discard the cloud backup and start over.',
        'La clave de este dispositivo no abre tu copia en la nube, así que no se guarda nada desde aquí. Restaura la clave que guardaste con Clave de recuperación de la copia. Si perdiste esa clave, puedes descartar la copia en la nube y empezar de nuevo.',
      ),
      CloudBackupKeyCheck.unreadable => _text(
        'This device\'s key opens your cloud backup, but the backup is damaged and cannot be restored. You can discard it and start over.',
        'La clave de este dispositivo abre tu copia en la nube, pero la copia está dañada y no se puede restaurar. Puedes descartarla y empezar de nuevo.',
      ),
      CloudBackupKeyCheck.newerVersion => _text(
        'Your cloud backup was made by a newer version of Axiomara, so this device cannot read it yet. Update Axiomara on this device.',
        'Tu copia en la nube la hizo una versión más nueva de Axiomara, así que este dispositivo aún no puede leerla. Actualiza Axiomara en este dispositivo.',
      ),
      CloudBackupKeyCheck.malformed => _text(
        'Your cloud backup could not be read. You can discard it and start over.',
        'No se pudo leer tu copia en la nube. Puedes descartarla y empezar de nuevo.',
      ),
      CloudBackupKeyCheck.unavailable => _text(
        'Could not check your cloud backup right now. Check your connection.',
        'Ahora no se pudo comprobar tu copia en la nube. Revisa tu conexión.',
      ),
      CloudBackupKeyCheck.ownerMismatch => _text(
        'The account signed in to the cloud is not the one this device is using. Sign in again, then reopen Settings.',
        'La cuenta conectada a la nube no es la que usa este dispositivo. Vuelve a iniciar sesión y abre de nuevo Ajustes.',
      ),
      CloudBackupKeyCheck.accountChanged => _text(
        'Your account changed while the backup was being checked. Reopen Settings to check again.',
        'Tu cuenta cambió mientras se comprobaba la copia. Abre de nuevo Ajustes para volver a comprobarla.',
      ),
    };
    if (keySaved || check == CloudBackupKeyCheck.noKeyOnDevice) return line;
    return '$line $notConfirmedNote';
  }
}

/// Bilingual copy for discarding a cloud backup this device cannot read.
final class CloudBackupDiscardCopy {
  const CloudBackupDiscardCopy({required this.isSpanish});

  final bool isSpanish;

  static CloudBackupDiscardCopy of(BuildContext context) =>
      CloudBackupDiscardCopy(
        isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
      );

  String _text(String english, String spanish) => isSpanish ? spanish : english;

  String get actionTitle => _text(
    'Discard cloud backup and start over',
    'Descartar la copia en la nube y empezar de nuevo',
  );

  String get actionSubtitle => _text(
    'Only if the recovery key is lost. Permanently deletes the cloud backup.',
    'Solo si perdiste la clave de recuperación. Borra la copia en la nube para siempre.',
  );

  String get firstStepTitle =>
      _text('Discard your cloud backup?', '¿Descartar tu copia en la nube?');

  String get firstStepBody => _text(
    'This device cannot open your cloud backup. If you saved the recovery key, or still have the device that made this backup, cancel and restore the key instead. Discarding permanently deletes the cloud backup for this account and cannot be undone. Data on this device is not changed, and the next backup starts again with this device\'s key.',
    'Este dispositivo no puede abrir tu copia en la nube. Si guardaste la clave de recuperación, o aún tienes el dispositivo que hizo esta copia, cancela y restaura la clave. Descartar borra para siempre la copia en la nube de esta cuenta y no se puede deshacer. Los datos de este dispositivo no cambian, y la próxima copia empieza de nuevo con la clave de este dispositivo.',
  );

  String get continueAction => _text('Continue', 'Continuar');

  String get secondStepTitle => _text(
    'Permanently delete the cloud backup?',
    '¿Borrar la copia en la nube para siempre?',
  );

  String get confirmationWord => _text('DISCARD', 'DESCARTAR');

  String get secondStepBody => _text(
    'Type $confirmationWord to confirm.',
    'Escribe $confirmationWord para confirmar.',
  );

  bool isConfirmation(String typed) =>
      typed.trim().toUpperCase() == confirmationWord;

  String get deleteAction =>
      _text('Delete cloud backup', 'Borrar copia en la nube');

  String outcome(CloudBackupDiscardOutcome outcome) => switch (outcome) {
    CloudBackupDiscardOutcome.discarded => _text(
      'Cloud backup discarded. The next backup from this device starts a new one with this device\'s key.',
      'Copia en la nube descartada. La próxima copia de este dispositivo empieza una nueva con la clave de este dispositivo.',
    ),
    CloudBackupDiscardOutcome.readable => _text(
      'This device can open the cloud backup now, so nothing was deleted.',
      'Este dispositivo ya puede abrir la copia en la nube, así que no se borró nada.',
    ),
    CloudBackupDiscardOutcome.newerVersion => _text(
      'Your cloud backup was made by a newer version of Axiomara, so nothing was deleted. Update Axiomara on this device.',
      'Tu copia en la nube la hizo una versión más nueva de Axiomara, así que no se borró nada. Actualiza Axiomara en este dispositivo.',
    ),
    CloudBackupDiscardOutcome.nothingToDiscard => _text(
      'There is no cloud backup to discard.',
      'No hay ninguna copia en la nube para descartar.',
    ),
    CloudBackupDiscardOutcome.noKeyOnDevice => _text(
      'This device has no recovery key yet, so nothing was deleted.',
      'Este dispositivo aún no tiene clave de recuperación, así que no se borró nada.',
    ),
    CloudBackupDiscardOutcome.changed => _text(
      'The cloud backup changed on another device, so nothing was deleted. Check its status again.',
      'La copia en la nube cambió en otro dispositivo, así que no se borró nada. Vuelve a comprobar su estado.',
    ),
    CloudBackupDiscardOutcome.refused => _text(
      'The server did not allow deleting the cloud backup, so nothing was deleted. This needs a server update, and is not possible while an account deletion is in progress.',
      'El servidor no permitió borrar la copia en la nube, así que no se borró nada. Esto necesita una actualización del servidor y no es posible mientras se elimina la cuenta.',
    ),
    CloudBackupDiscardOutcome.unavailable => _text(
      'Could not reach your cloud backup, so nothing was deleted. Check your connection and try again.',
      'No se pudo conectar con tu copia en la nube, así que no se borró nada. Revisa tu conexión e inténtalo de nuevo.',
    ),
    CloudBackupDiscardOutcome.ownerMismatch => _text(
      'The account signed in to the cloud is not the one this device is using, so nothing was deleted.',
      'La cuenta conectada a la nube no es la que usa este dispositivo, así que no se borró nada.',
    ),
    CloudBackupDiscardOutcome.accountChanged => _text(
      'Your account changed before the backup could be discarded, so nothing was deleted.',
      'Tu cuenta cambió antes de poder descartar la copia, así que no se borró nada.',
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
