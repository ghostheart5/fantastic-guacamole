import 'package:fantastic_guacamole/features/permissions/permission_denied_recovery.dart';
import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';

class VoicePermissionPrompt extends StatelessWidget {
  const VoicePermissionPrompt({
    super.key,
    required this.permissionGranted,
    required this.onRequestPermission,
    required this.onOpenSystemSettings,
    this.title = 'Voice Access',
  });

  final bool? permissionGranted;
  final Future<bool> Function() onRequestPermission;
  final Future<void> Function() onOpenSystemSettings;
  final String title;

  @override
  Widget build(BuildContext context) {
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
                        const Text(
                          'PERMISSION · MICROPHONE',
                          style: TextStyle(
                            color: AppColors.neonViolet,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
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
              const Text(
                'Allow microphone access to use voice-to-text and spoken Smart Planner guidance in the SI Console.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              const TemporalStatusRow(
                icon: Icons.mic_off_outlined,
                text: 'No background recording.',
                color: AppColors.neonViolet,
              ),
              const SizedBox(height: 14),
              TemporalActionButton(
                label: 'Enable Voice Access',
                icon: Icons.mic_none_rounded,
                accent: AppColors.neonViolet,
                onPressed: () async {
                  await showPermissionRationaleSheet<void>(
                    context: context,
                    explainer: PermissionExplainers.voice,
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
            title: 'Microphone Permission Denied',
            message:
                'Microphone access is currently blocked. Open system settings to enable voice features.',
            onOpenSystemSettings: onOpenSystemSettings,
          ),
        ],
      ],
    );
  }
}
