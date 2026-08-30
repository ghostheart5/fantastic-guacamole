import 'package:fantastic_guacamole/system/external_url_service.dart';
import 'package:flutter/material.dart';

typedef SafetySupportLauncher = Future<bool> Function(Uri uri);

enum SupportiveDistressChoice { pause, continueWithGentleQuestion }

@immutable
final class SafetySupportResources {
  const SafetySupportResources({
    required this.regionCode,
    required this.directoryUri,
    this.crisisCallUri,
    this.crisisTextUri,
    this.emergencyCallUri,
  });

  final String regionCode;
  final Uri directoryUri;
  final Uri? crisisCallUri;
  final Uri? crisisTextUri;
  final Uri? emergencyCallUri;

  static SafetySupportResources resolve(Locale locale) {
    final String region = locale.countryCode?.toUpperCase() ?? '';
    return switch (region) {
      'US' => SafetySupportResources(
        regionCode: region,
        directoryUri: Uri.https('findahelpline.com', '/'),
        crisisCallUri: Uri(scheme: 'tel', path: '988'),
        crisisTextUri: Uri(scheme: 'sms', path: '988'),
        emergencyCallUri: Uri(scheme: 'tel', path: '911'),
      ),
      'CA' => SafetySupportResources(
        regionCode: region,
        directoryUri: Uri.https('findahelpline.com', '/'),
        crisisCallUri: Uri(scheme: 'tel', path: '988'),
        crisisTextUri: Uri(scheme: 'sms', path: '988'),
        emergencyCallUri: Uri(scheme: 'tel', path: '911'),
      ),
      'ES' => SafetySupportResources(
        regionCode: region,
        directoryUri: Uri.https('findahelpline.com', '/'),
        crisisCallUri: Uri(scheme: 'tel', path: '024'),
        emergencyCallUri: Uri(scheme: 'tel', path: '112'),
      ),
      _ => SafetySupportResources(
        regionCode: 'GLOBAL',
        directoryUri: Uri.https('findahelpline.com', '/'),
      ),
    };
  }
}

Future<void> showCrisisDialog(
  BuildContext context, {
  Locale? locale,
  SafetySupportLauncher? launcher,
}) {
  final Locale resolvedLocale =
      locale ?? WidgetsBinding.instance.platformDispatcher.locale;
  final _SafetySupportCopy copy = _SafetySupportCopy(resolvedLocale);
  final SafetySupportResources resources = SafetySupportResources.resolve(
    resolvedLocale,
  );
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) => _SafetySupportDialog(
      copy: copy,
      resources: resources,
      launcher: launcher ?? _launchSafetySupport,
      immediate: true,
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

Future<SupportiveDistressChoice> showSupportiveDistressDialog(
  BuildContext context, {
  Locale? locale,
  SafetySupportLauncher? launcher,
}) async {
  final Locale resolvedLocale =
      locale ?? WidgetsBinding.instance.platformDispatcher.locale;
  final _SafetySupportCopy copy = _SafetySupportCopy(resolvedLocale);
  final SafetySupportResources resources = SafetySupportResources.resolve(
    resolvedLocale,
  );
  return await showDialog<SupportiveDistressChoice>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => _SafetySupportDialog(
          copy: copy,
          resources: resources,
          launcher: launcher ?? _launchSafetySupport,
          immediate: false,
          onClose: () =>
              Navigator.of(dialogContext).pop(SupportiveDistressChoice.pause),
          onContinue: () => Navigator.of(
            dialogContext,
          ).pop(SupportiveDistressChoice.continueWithGentleQuestion),
        ),
      ) ??
      SupportiveDistressChoice.pause;
}

Future<bool> _launchSafetySupport(Uri uri) {
  return const ExternalUrlService().open(uri);
}

final class _SafetySupportDialog extends StatefulWidget {
  const _SafetySupportDialog({
    required this.copy,
    required this.resources,
    required this.launcher,
    required this.immediate,
    required this.onClose,
    this.onContinue,
  });

  final _SafetySupportCopy copy;
  final SafetySupportResources resources;
  final SafetySupportLauncher launcher;
  final bool immediate;
  final VoidCallback onClose;
  final VoidCallback? onContinue;

  @override
  State<_SafetySupportDialog> createState() => _SafetySupportDialogState();
}

final class _SafetySupportDialogState extends State<_SafetySupportDialog> {
  bool _opening = false;
  String? _actionError;

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _actionError = null;
    });
    final bool opened = await widget.launcher(uri);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _actionError = opened ? null : widget.copy.openError;
    });
  }

  Uri get _trustedContactUri => Uri(
    scheme: 'sms',
    queryParameters: <String, String>{'body': widget.copy.trustedMessage},
  );

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Widget> actions = <Widget>[
      if (widget.resources.emergencyCallUri case final Uri emergencyUri)
        _SafetyAction(
          key: const Key('safety-call-emergency'),
          icon: Icons.emergency_outlined,
          label: widget.copy.emergencyLabel(widget.resources.regionCode),
          onPressed: _opening ? null : () => _open(emergencyUri),
          emphasized: true,
        ),
      if (widget.resources.crisisCallUri case final Uri crisisCallUri)
        _SafetyAction(
          key: const Key('safety-call-crisis'),
          icon: Icons.call_outlined,
          label: widget.copy.crisisCallLabel(widget.resources.regionCode),
          onPressed: _opening ? null : () => _open(crisisCallUri),
        ),
      if (widget.resources.crisisTextUri case final Uri crisisTextUri)
        _SafetyAction(
          key: const Key('safety-text-crisis'),
          icon: Icons.sms_outlined,
          label: widget.copy.crisisTextLabel,
          onPressed: _opening ? null : () => _open(crisisTextUri),
        ),
      _SafetyAction(
        key: const Key('safety-contact-trusted'),
        icon: Icons.person_outline,
        label: widget.copy.trustedLabel,
        onPressed: _opening ? null : () => _open(_trustedContactUri),
      ),
      _SafetyAction(
        key: const Key('safety-find-local-support'),
        icon: Icons.public_outlined,
        label: widget.copy.directoryLabel,
        onPressed: _opening ? null : () => _open(widget.resources.directoryUri),
      ),
    ];

    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: Key(
          widget.immediate
              ? 'immediate-safety-dialog'
              : 'supportive-distress-dialog',
        ),
        backgroundColor: colors.surface,
        title: Text(
          widget.immediate ? widget.copy.crisisTitle : widget.copy.supportTitle,
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.immediate
                      ? widget.copy.crisisBody
                      : widget.copy.supportBody,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                ...actions.expand(
                  (Widget action) => <Widget>[
                    action,
                    const SizedBox(height: 8),
                  ],
                ),
                if (_actionError != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _actionError!,
                    key: const Key('safety-action-error'),
                    style: TextStyle(color: colors.error),
                  ),
                ],
                if (!widget.immediate) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    widget.copy.continueDisclosure,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('safety-pause'),
            onPressed: widget.onClose,
            child: Text(
              widget.immediate
                  ? widget.copy.closeLabel
                  : widget.copy.pauseLabel,
            ),
          ),
          if (!widget.immediate)
            FilledButton(
              key: const Key('safety-continue-gently'),
              onPressed: widget.onContinue,
              child: Text(widget.copy.continueLabel),
            ),
        ],
      ),
    );
  }
}

final class _SafetyAction extends StatelessWidget {
  const _SafetyAction({
    required super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final Widget button = emphasized
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return SizedBox(width: double.infinity, child: button);
  }
}

final class _SafetySupportCopy {
  const _SafetySupportCopy(this.locale);

  final Locale locale;

  bool get _es => locale.languageCode.toLowerCase() == 'es';

  String get crisisTitle => _es
      ? 'Paremos y centrémonos en tu seguridad'
      : "Let's pause and focus on your safety";

  String get crisisBody => _es
      ? 'ChronoSpark ha pausado la planificación normal porque este mensaje puede involucrar seguridad inmediata. Es una precaución de enrutamiento, no un juicio ni un diagnóstico. Si hay peligro inmediato o una emergencia médica, contacta ahora con los servicios de emergencia locales.'
      : 'ChronoSpark paused ordinary planning because this message may involve immediate safety. This is a routing precaution, not a judgment or diagnosis. If there is immediate danger or a medical emergency, contact local emergency services now.';

  String get supportTitle => _es
      ? '¿Qué apoyo te ayudaría ahora?'
      : 'What support would help right now?';

  String get supportBody => _es
      ? 'ChronoSpark ha pausado la productividad porque tus palabras pueden describir angustia. No es un diagnóstico. Puedes parar aquí, contactar a alguien de confianza, buscar apoyo local o elegir una sola pregunta suave.'
      : 'ChronoSpark paused productivity because your words may describe distress. This is not a diagnosis. You can stop here, contact someone you trust, find local support, or choose one gentle question.';

  String emergencyLabel(String regionCode) => switch (regionCode) {
    'US' || 'CA' => _es ? 'Llamar al 911' : 'Call 911',
    'ES' => _es ? 'Llamar al 112' : 'Call 112',
    _ => _es ? 'Servicios de emergencia locales' : 'Local emergency services',
  };

  String crisisCallLabel(String regionCode) => switch (regionCode) {
    'ES' => _es ? 'Llamar a la Línea 024' : 'Call Spain 024',
    _ => _es ? 'Llamar al 988' : 'Call 988',
  };

  String get crisisTextLabel => _es ? 'Enviar mensaje al 988' : 'Text 988';
  String get trustedLabel =>
      _es ? 'Contactar a alguien de confianza' : 'Contact someone I trust';
  String get directoryLabel =>
      _es ? 'Buscar apoyo local verificado' : 'Find verified local support';
  String get pauseLabel => _es ? 'Pausar por ahora' : 'Pause for now';
  String get closeLabel => _es ? 'Cerrar' : 'Close';
  String get continueLabel => _es
      ? 'Continuar con una pregunta suave'
      : 'Continue with one gentle question';
  String get continueDisclosure => _es
      ? 'Continuar no guardará, moverá ni completará nada. ChronoSpark hará una pregunta antes de sugerir acciones.'
      : 'Continuing will not save, move, or complete anything. ChronoSpark will ask one question before suggesting actions.';
  String get openError => _es
      ? 'Este dispositivo no pudo abrir esa opción. Usa otro teléfono o navegador si necesitas apoyo ahora.'
      : 'This device could not open that option. Use another phone or browser if you need support now.';
  String get trustedMessage => _es
      ? 'Estoy pasando por un momento difícil y me gustaría recibir apoyo. ¿Puedes comunicarte conmigo cuando sea seguro?'
      : "I'm having a difficult time and would like support. Can you contact me when it is safe?";
}
