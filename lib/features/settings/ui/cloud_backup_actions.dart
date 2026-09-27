import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
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
    if (!scope.isWritable) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (restore) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              journeyText(
                context,
                'Restore cloud backup?',
                '¿Restaurar la copia en la nube?',
              ),
            ),
            content: Text(
              journeyText(
                context,
                'This replaces tasks, profile and settings on this device with your verified cloud backup. Other local planning data is not restored. Continue only if you want to replace these device values.',
                'Esto reemplaza las tareas, el perfil y los ajustes de este dispositivo por tu copia verificada en la nube. Los demás datos locales de planificación no se restauran. Continúa solo si deseas reemplazar estos valores.',
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
                  journeyText(context, 'Restore backup', 'Restaurar copia'),
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
          ref.read(accountStorageScopeProvider).v2Namespace !=
              scope.v2Namespace) {
        return;
      }
      setState(() => _transferStarted = true);
      final success = restore
          ? await ref.refresh(restoreFromCloudProvider.future)
          : await ref.refresh(syncToCloudProvider.future);
      if (!mounted ||
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
                      'Encrypted cloud backup saved.',
                      'Copia cifrada guardada en la nube.',
                    )
            : journeyText(
                context,
                'The cloud operation could not finish. Check your connection and recovery key, then review your local data before trying again.',
                'La operación en la nube no pudo finalizar. Revisa la conexión y la clave de recuperación, y luego tus datos locales antes de volver a intentarlo.',
              );
      });
    } on Object {
      if (!mounted ||
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
              journeyText(context, 'Back up now', 'Guardar copia ahora'),
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
