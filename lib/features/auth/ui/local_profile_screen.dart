import 'package:fantastic_guacamole/state/services/auth_gateway_support.dart';
import 'package:flutter/material.dart';

/// Entry for production device profiles, including interrupted deletion retry.
class LocalProfileScreen extends StatefulWidget {
  const LocalProfileScreen({required this.service, super.key});
  final LocalProfileAuthService service;

  @override
  State<LocalProfileScreen> createState() => _LocalProfileScreenState();
}

class _LocalProfileScreenState extends State<LocalProfileScreen> {
  final TextEditingController _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = widget.service;
      if (service.hasPendingDeletion) {
        await service.deleteCurrentAccount(password: '');
      } else if (service.hasStoredProfile) {
        await service.openProfile();
      } else {
        await service.createProfile(displayName: _name.text);
      }
    } on Object {
      if (mounted) {
        setState(
          () => _error = widget.service.hasPendingDeletion
              ? 'Deletion is incomplete. Your profile remains closed. Retry to finish removing its data.'
              : 'Your local profile could not be opened. Retry; your saved profile has not been replaced.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool deleting = widget.service.hasPendingDeletion;
    final bool existing = widget.service.hasStoredProfile;
    final bool spanish = Localizations.localeOf(context).languageCode == 'es';
    String copy(String en, String es) => spanish ? es : en;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(Icons.person_outline, size: 48),
                  const SizedBox(height: 20),
                  Text(
                    deleting
                        ? copy(
                            'Finish deleting your local profile',
                            'Completa la eliminación de tu perfil local',
                          )
                        : existing
                        ? copy(
                            'Open your local profile',
                            'Abre tu perfil local',
                          )
                        : copy(
                            'Create a local profile',
                            'Crea un perfil local',
                          ),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    deleting
                        ? copy(
                            'A previous deletion did not finish. This profile stays closed until its saved data and notifications have been removed.',
                            'Una eliminación anterior no terminó. Este perfil permanece cerrado hasta que se eliminen sus datos y notificaciones.',
                          )
                        : copy(
                            'Your planning data stays on this device. No email or online account is created. There is no cloud backup, sync, or password recovery. Removing the app or losing this device can permanently lose your data. Protect access with your device lock.',
                            'Tus datos de planificación permanecen en este dispositivo. No se crea un correo ni una cuenta en línea. No hay copia en la nube, sincronización ni recuperación de contraseña. Eliminar la app o perder el dispositivo puede hacer que pierdas tus datos permanentemente. Protege el acceso con el bloqueo del dispositivo.',
                          ),
                  ),
                  if (!existing) ...<Widget>[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: copy('Name (optional)', 'Nombre (opcional)'),
                      ),
                    ),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('local-profile-continue'),
                    onPressed: _busy ? null : _continue,
                    child: Text(
                      _busy
                          ? copy('Please wait', 'Espera')
                          : deleting
                          ? copy('Retry deletion', 'Reintentar eliminación')
                          : existing
                          ? copy('Open profile', 'Abrir perfil')
                          : copy('Create profile', 'Crear perfil'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
