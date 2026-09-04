import 'package:fantastic_guacamole/features/permissions/permission_denied_recovery.dart';
import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';

class VoicePermissionPrompt extends StatelessWidget {
  const VoicePermissionPrompt({
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
      PermissionKind.microphone,
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
          accent: AppColors.neonViolet,
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
                      Icons.mic_none_rounded,
                      color: AppColors.neonViolet,
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
                              ? 'PERMISO · MICRÓFONO'
                              : 'PERMISSION · MICROPHONE',
                          style: const TextStyle(
                            color: AppColors.neonViolet,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title ??
                              (isSpanish
                                  ? 'Entrada por micrófono'
                                  : 'Microphone Input'),
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
                    ? 'Permite el micrófono solo cuando quieras dictar texto en Planificador Inteligente o Consola SI. La reproducción hablada no requiere acceso al micrófono.'
                    : 'Allow microphone access only when you want to dictate text in Smart Planner or the SI Console. Spoken playback does not require microphone access.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              TemporalStatusRow(
                icon: Icons.mic_off_outlined,
                text: isSpanish
                    ? 'No graba en segundo plano.'
                    : 'No background recording.',
                color: AppColors.neonViolet,
              ),
              const SizedBox(height: 8),
              TemporalStatusRow(
                icon: Icons.volume_up_outlined,
                text: isSpanish
                    ? 'La reproducción hablada funciona sin acceso al micrófono.'
                    : 'Spoken playback works without microphone access.',
                color: AppColors.neonViolet,
              ),
              const SizedBox(height: 14),
              TemporalActionButton(
                label: isSpanish
                    ? 'Activar entrada por micrófono'
                    : 'Enable Microphone Input',
                icon: Icons.mic_none_rounded,
                accent: AppColors.neonViolet,
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
            title: isSpanish
                ? 'Permiso de micrófono denegado'
                : 'Microphone Permission Denied',
            message: isSpanish
                ? 'El acceso al micrófono está bloqueado. Abre los ajustes del sistema para activar la entrada de voz. La reproducción hablada sigue disponible sin acceso al micrófono.'
                : 'Microphone access is blocked. Open system settings to enable speech input. Spoken playback remains available without microphone access.',
            onOpenSystemSettings: onOpenSystemSettings,
          ),
        ],
      ],
    );
  }
}
