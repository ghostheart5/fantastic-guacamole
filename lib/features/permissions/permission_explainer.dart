import 'package:flutter/foundation.dart';

enum PermissionKind { notifications, microphone }

@immutable
class PermissionExplainer {
  const PermissionExplainer({
    required this.kind,
    required this.title,
    required this.whyItMatters,
    required this.whenUsed,
    required this.primaryActionLabel,
    this.secondaryActionLabel = 'Not Now',
  });

  final PermissionKind kind;
  final String title;
  final String whyItMatters;
  final String whenUsed;
  final String primaryActionLabel;
  final String secondaryActionLabel;
}

class PermissionExplainers {
  const PermissionExplainers._();

  static const PermissionExplainer notification = PermissionExplainer(
    kind: PermissionKind.notifications,
    title: 'Enable Notifications',
    whyItMatters:
        'Notifications help you keep momentum by surfacing reflection and execution reminders at the right time.',
    whenUsed:
        'Used only for reminders you configure in app settings. You can disable them any time.',
    primaryActionLabel: 'Allow Notifications',
  );

  static const PermissionExplainer microphone = PermissionExplainer(
    kind: PermissionKind.microphone,
    title: 'Enable Microphone Input',
    whyItMatters:
        'Microphone access lets you dictate thoughts after choosing a microphone control in Smart Planner or the SI Console.',
    whenUsed:
        'Used only for user-initiated speech input. Spoken playback does not require microphone access, and audio is never captured during normal planning or background use.',
    primaryActionLabel: 'Allow Microphone',
  );

  static const PermissionExplainer notificationSpanish = PermissionExplainer(
    kind: PermissionKind.notifications,
    title: 'Activar notificaciones',
    whyItMatters:
        'Las notificaciones ayudan a mantener el impulso mostrando recordatorios de reflexión y ejecución en el momento que elijas.',
    whenUsed:
        'Solo se usan para recordatorios que programes o actives. ChronoSpark sigue funcionando si no das permiso.',
    primaryActionLabel: 'Permitir notificaciones',
    secondaryActionLabel: 'Ahora no',
  );

  static const PermissionExplainer microphoneSpanish = PermissionExplainer(
    kind: PermissionKind.microphone,
    title: 'Activar entrada por micrófono',
    whyItMatters:
        'El acceso al micrófono te permite dictar texto después de elegir un control de micrófono en Planificador Inteligente o Consola SI.',
    whenUsed:
        'Se usa solo para entrada de voz iniciada por ti. La reproducción hablada no requiere acceso al micrófono y nunca se captura audio durante la planificación normal ni en segundo plano.',
    primaryActionLabel: 'Permitir micrófono',
    secondaryActionLabel: 'Ahora no',
  );

  static PermissionExplainer forKind(
    PermissionKind kind, {
    required bool isSpanish,
  }) => switch (kind) {
    PermissionKind.notifications =>
      isSpanish ? notificationSpanish : notification,
    PermissionKind.microphone => isSpanish ? microphoneSpanish : microphone,
  };
}
