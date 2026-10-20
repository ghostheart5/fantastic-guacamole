import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloudBackupActions extends ConsumerStatefulWidget {
  const CloudBackupActions({super.key, required this.enabled});
  final bool enabled;

  @override
  ConsumerState<CloudBackupActions> createState() => CloudBackupActionsState();
}

class CloudBackupActionsState extends ConsumerState<CloudBackupActions> {
  bool _busy = false;
  bool _transferStarted = false;
  String? _message;

  Future<void> _transfer({required bool restore}) async {
    if (_busy || !widget.enabled) {
      return;
    }
    final scope = ref.read(accountStorageScopeProvider);
    final generation = ref.read(authSessionBoundaryProvider).generation;
    if (!scope.isWritable) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(
              journeyText(
                context,
                restore
                    ? 'Restore cloud backup?'
                    : 'Back up all planning data?',
                restore
                    ? '¿Restaurar la copia en la nube?'
                    : '¿Guardar todos los datos de planificación?',
              ),
            ),
            content: Text(
              journeyText(
                context,
                restore
                    ? 'This replaces the planning data included in your verified cloud backup on this device. Full backups include tasks, goals, Daily Rhythms, notes, outcome and schedule history, profile and settings. Older backups may only include tasks, profile and settings. Review your local data before continuing.'
                    : 'Send an encrypted snapshot of tasks, goals, Daily Rhythms, notes, outcome and schedule history, profile and settings to your account. This replaces your previous cloud snapshot with this device’s data. Restore the latest backup first if you are using a replacement device. Private memories and Person Context stay on this device.',
                restore
                    ? 'Esto reemplaza en este dispositivo los datos incluidos en tu copia verificada. Las copias completas incluyen tareas, metas, ritmos diarios, notas, historial de resultados y cronología, perfil y ajustes. Las copias anteriores pueden incluir solo tareas, perfil y ajustes. Revisa los datos locales antes de continuar.'
                    : 'Envía a tu cuenta una copia cifrada de tareas, metas, ritmos diarios, notas, historial de resultados y cronología, perfil y ajustes. Reemplaza la copia anterior con los datos de este dispositivo. Restaura primero la copia más reciente si usas otro dispositivo. Las memorias privadas y el Contexto Personal permanecen aquí.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(journeyText(context, 'Cancel', 'Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  journeyText(
                    context,
                    restore ? 'Restore backup' : 'Save planning backup',
                    restore
                        ? 'Restaurar copia'
                        : 'Guardar copia de planificación',
                  ),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) {
          return;
        }
      }
      if (!widget.enabled ||
          ref.read(authSessionBoundaryProvider).generation != generation ||
          ref.read(accountStorageScopeProvider).v2Namespace !=
              scope.v2Namespace) {
        return;
      }
      setState(() => _transferStarted = true);
      final success = restore
          ? await ref.refresh(restoreFromCloudProvider.future)
          : await ref.refresh(backupPlanningToCloudProvider.future);
      if (!mounted ||
          ref.read(authSessionBoundaryProvider).generation != generation ||
          ref.read(accountStorageScopeProvider).v2Namespace !=
              scope.v2Namespace) {
        return;
      }
      setState(() {
        _message = success
            ? restore
                  ? journeyText(
                      context,
                      'Cloud backup restored.',
                      'Copia en la nube restaurada.',
                    )
                  : journeyText(
                      context,
                      'Encrypted planning backup saved and verified.',
                      'Copia cifrada de planificación guardada y verificada.',
                    )
            : journeyText(
                context,
                'The cloud operation could not finish. Check your connection and recovery key, then review your local data before trying again.',
                'La operación en la nube no pudo finalizar. Revisa la conexión y la clave de recuperación, y luego tus datos locales antes de volver a intentarlo.',
              );
        if (success && restore) {
          final warnings = ref.read(cloudRestoreWarningsProvider);
          if (warnings.contains(CloudRestoreWarning.legacyCleanupPending)) {
            _message =
                '${_message!} ${journeyText(context, 'An older cloud copy still needs secure cleanup. Do not treat this restore as fully finished.', 'Una copia anterior en la nube aún necesita una limpieza segura. La restauración no ha finalizado por completo.')}';
          }
          if (warnings.contains(CloudRestoreWarning.remindersPending)) {
            _message =
                '${_message!} ${journeyText(context, 'Device reminders could not all be updated. Review reminder settings and notification permission on this device.', 'No se pudieron actualizar todos los recordatorios. Revisa sus ajustes y el permiso de notificaciones en este dispositivo.')}';
          }
        }
      });
    } on Object {
      if (!mounted ||
          ref.read(authSessionBoundaryProvider).generation != generation ||
          ref.read(accountStorageScopeProvider).v2Namespace !=
              scope.v2Namespace) {
        return;
      }
      setState(
        () => _message = journeyText(
          context,
          'The cloud operation could not finish. Review your local data before trying again.',
          'La operación en la nube no pudo finalizar. Revisa tus datos locales antes de volver a intentarlo.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _transferStarted = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: widget.enabled && !_busy
                ? () => _transfer(restore: false)
                : null,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              journeyText(
                context,
                'Back up all planning data',
                'Guardar todos los datos',
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: widget.enabled && !_busy
                ? () => _transfer(restore: true)
                : null,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              journeyText(
                context,
                'Restore cloud backup',
                'Restaurar copia en la nube',
              ),
            ),
          ),
          if (_transferStarted) const LinearProgressIndicator(),
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!)),
        ],
      ),
    );
  }
}
