import 'package:fantastic_guacamole/features/permissions/permission_denied_recovery.dart';
import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';

class NotificationPermissionPrompt extends StatelessWidget {
  const NotificationPermissionPrompt({
    super.key,
    required this.permissionGranted,
    required this.onRequestPermission,
    required this.onOpenSystemSettings,
    this.title,
  });

  final bool? permissionGranted;
  final Future<bool> Function() onRequestPermission;
  final Future<void> Function() onOpenSystemSettings;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
    final PermissionExplainer explainer = PermissionExplainers.forKind(
      PermissionKind.notifications,
      isSpanish: isSpanish,
    );
    final bool granted = permissionGranted == true;
    final bool denied = permissionGranted == false;

    if (granted) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TemporalGlassSurface(
          accent: AppColors.neonCyan,
          opacity: 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox.square(
                    dimension: 48,
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.neonCyan,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isSpanish
                              ? 'PERMISO · NOTIFICACIONES'
                              : 'PERMISSION · NOTIFICATIONS',
                          style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title ??
                              (isSpanish ? 'Notificaciones' : 'Notifications'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isSpanish
                    ? 'Activa las notificaciones para recibir los recordatorios de ejecución y reflexión que programes.'
                    : 'Enable notifications to receive scheduled execution and reflection reminders.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              TemporalStatusRow(
                icon: Icons.tune_rounded,
                text: isSpanish
                    ? 'Opcionales y controladas desde Ajustes.'
                    : 'Optional and controlled from Settings.',
              ),
              const SizedBox(height: 14),
              TemporalActionButton(
                label: isSpanish
                    ? 'Activar notificaciones'
                    : 'Enable Notifications',
                icon: Icons.notifications_active_outlined,
                onPressed: () async {
                  await showPermissionRationaleSheet<void>(
                    context: context,
                    explainer: explainer,
                    onPrimary: () async {
                      await onRequestPermission();
                    },
                  );
                },
              ),
            ],
          ),
        ),
        if (denied) ...<Widget>[
          const SizedBox(height: 10),
          PermissionDeniedRecovery(
            title: isSpanish ? 'Permiso denegado' : 'Permission Denied',
            message: isSpanish
                ? 'Las notificaciones están desactivadas en el sistema. Abre los ajustes para volver a activar los avisos.'
                : 'Notifications are disabled at system level. Open settings to re-enable alerts.',
            onOpenSystemSettings: onOpenSystemSettings,
          ),
        ],
      ],
    );
  }
}
