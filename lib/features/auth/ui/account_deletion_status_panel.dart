import 'dart:async';

import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/auth_provider.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public, signed-out recovery surface for an asynchronous account deletion.
/// The underlying status capability remains confined to secure storage.
class AccountDeletionStatusPanel extends ConsumerStatefulWidget {
  const AccountDeletionStatusPanel({super.key});

  @override
  ConsumerState<AccountDeletionStatusPanel> createState() =>
      _AccountDeletionStatusPanelState();
}

class _AccountDeletionStatusPanelState
    extends ConsumerState<AccountDeletionStatusPanel> {
  _AccountDeletionDisplayStatus? _status;
  bool _loading = true;
  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final status = await ref
          .read(authServiceProvider)
          .readPendingAccountDeletion();
      if (!mounted) return;
      setState(() {
        _status = status == null
            ? null
            : _AccountDeletionDisplayStatus(
                serverState: status.serverState,
                createdAtUtc: status.createdAtUtc,
                localCleanupCompleted: status.localCleanupCompleted,
              );
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _copy.statusUnavailable;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(authServiceProvider)
          .refreshPendingAccountDeletion();
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _status = null;
          _loading = false;
          _error = _copy.receiptUnavailable;
        });
        return;
      }
      if (result.isCompleted) {
        setState(() {
          _completed = true;
          _status = null;
          _loading = false;
        });
        return;
      }
      final refreshed = await ref
          .read(authServiceProvider)
          .readPendingAccountDeletion();
      if (!mounted) return;
      setState(() {
        _status = refreshed == null
            ? null
            : _AccountDeletionDisplayStatus(
                serverState: refreshed.serverState,
                createdAtUtc: refreshed.createdAtUtc,
                localCleanupCompleted: refreshed.localCleanupCompleted,
              );
        _loading = false;
        _error = refreshed == null ? _copy.receiptUnavailable : null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _copy.refreshFailed;
      });
    }
  }

  Future<void> _forget() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(_copy.stopTrackingTitle),
            content: Text(_copy.stopTrackingBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(_copy.keepTracking),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(_copy.stopTracking),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await ref.read(authServiceProvider).forgetPendingAccountDeletion();
      if (!mounted) return;
      setState(() {
        _status = null;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _error = _copy.stopTrackingFailed);
    }
  }

  _AccountDeletionStatusCopy get _copy => _AccountDeletionStatusCopy(
    ChronoSparkLocalizations.of(context).isSpanish,
  );

  @override
  Widget build(BuildContext context) {
    if (!_loading && _status == null && !_completed && _error == null) {
      return const SizedBox.shrink();
    }
    final _AccountDeletionStatusCopy copy = _copy;
    final _AccountDeletionDisplayStatus? status = _status;
    return TemporalGlassSurface(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: copy.title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(copy.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_completed)
              Text(copy.completed)
            else ...<Widget>[
              if (status != null) ...<Widget>[
                Text(copy.stateLabel(status.serverState)),
                const SizedBox(height: 6),
                Text(copy.startedLabel(status.createdAtUtc)),
                if (!status.localCleanupCompleted) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    copy.localCleanupIncomplete,
                    style: const TextStyle(color: Colors.amber),
                  ),
                ],
              ],
              if (_error != null) ...<Widget>[
                if (status != null) const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.amber)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (status != null)
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(copy.checkStatus),
                    ),
                  if (status != null)
                    TextButton(
                      onPressed: _forget,
                      child: Text(copy.stopTracking),
                    ),
                  if (status == null && _error != null)
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(copy.tryAgain),
                    ),
                ],
              ),
              if (status != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(copy.recoveryHelp),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

final class _AccountDeletionDisplayStatus {
  const _AccountDeletionDisplayStatus({
    required this.serverState,
    required this.createdAtUtc,
    required this.localCleanupCompleted,
  });

  final String serverState;
  final DateTime createdAtUtc;
  final bool localCleanupCompleted;
}

final class _AccountDeletionStatusCopy {
  const _AccountDeletionStatusCopy(this.isSpanish);

  final bool isSpanish;

  String get title => isSpanish
      ? 'Estado de eliminación de la cuenta'
      : 'Account deletion status';
  String get completed => isSpanish
      ? 'La eliminación de la cuenta se completó. El recibo de estado se borró de este dispositivo.'
      : 'Account deletion completed. The status receipt was removed from this device.';
  String get statusUnavailable => isSpanish
      ? 'No se pudo leer el recibo de estado guardado de forma segura.'
      : 'The securely saved status receipt could not be read.';
  String get receiptUnavailable => isSpanish
      ? 'Ya no hay un recibo de estado disponible en este dispositivo.'
      : 'A status receipt is no longer available on this device.';
  String get refreshFailed => isSpanish
      ? 'No se pudo confirmar el estado. Comprueba la conexión e inténtalo de nuevo.'
      : 'Status could not be confirmed. Check your connection and retry.';
  String get localCleanupIncomplete => isSpanish
      ? 'La solicitud del servidor fue aceptada, pero la limpieza local necesita atención.'
      : 'The server request was accepted, but local cleanup still needs attention.';
  String get checkStatus => isSpanish ? 'Comprobar estado' : 'Check status';
  String get tryAgain => isSpanish ? 'Intentar de nuevo' : 'Try again';
  String get stopTracking =>
      isSpanish ? 'Dejar de seguir' : 'Stop tracking on this device';
  String get stopTrackingTitle => isSpanish
      ? '¿Dejar de seguir la eliminación?'
      : 'Stop tracking deletion?';
  String get stopTrackingBody => isSpanish
      ? 'Esto elimina el recibo privado de este dispositivo. Ya no podrás comprobar el estado aquí.'
      : 'This removes the private receipt from this device. You will no longer be able to check status here.';
  String get keepTracking => isSpanish ? 'Seguir comprobando' : 'Keep tracking';
  String get stopTrackingFailed => isSpanish
      ? 'No se pudo eliminar el recibo de estado.'
      : 'The status receipt could not be removed.';
  String get recoveryHelp => isSpanish
      ? 'Si el estado no cambia, usa la página alojada o el canal de soporte indicado arriba.'
      : 'If the status does not change, use the hosted page or support path above.';

  String stateLabel(String state) {
    final String label = switch (state) {
      'requested' => isSpanish ? 'Solicitud recibida' : 'Request received',
      'sessions_revoked' =>
        isSpanish
            ? 'Acceso de la cuenta revocado; limpieza en curso'
            : 'Signed-in access revoked; cleanup in progress',
      'storage_deleted' =>
        isSpanish
            ? 'Almacenamiento eliminado; finalización en curso'
            : 'Storage deleted; finalizing',
      _ => isSpanish ? 'Limpieza en curso' : 'Cleanup in progress',
    };
    return isSpanish ? 'Estado: $label' : 'Status: $label';
  }

  String startedLabel(DateTime createdAtUtc) {
    final String date = createdAtUtc
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    return isSpanish ? 'Solicitud iniciada: $date' : 'Request started: $date';
  }
}
