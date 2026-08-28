import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/constants/app_sizes.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';

Future<T?> showPermissionRationaleSheet<T>({
  required BuildContext context,
  required PermissionExplainer explainer,
  required Future<void> Function() onPrimary,
  VoidCallback? onSecondary,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
    ),
    builder: (BuildContext modalContext) {
      final bool isVoice = explainer.title == PermissionExplainers.voice.title;
      final Color accent = isVoice ? AppColors.neonViolet : AppColors.neonCyan;
      final IconData permissionIcon = isVoice
          ? Icons.mic_none_rounded
          : Icons.notifications_active_outlined;
      final List<(IconData, String)> facts = isVoice
          ? <(IconData, String)>[
              (
                Icons.touch_app_outlined,
                'Starts only after you choose a voice control',
              ),
              (Icons.mic_off_outlined, 'No background recording'),
              (Icons.settings_outlined, 'Disable microphone access any time'),
            ]
          : <(IconData, String)>[
              (Icons.schedule_outlined, 'Only at times you choose'),
              (Icons.tune_rounded, 'Controlled from Settings'),
              (
                Icons.notifications_off_outlined,
                'Optional; the app still works without it',
              ),
            ];
      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
        ),
        child: TemporalGlassSurface(
          accent: accent,
          opacity: 0.96,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Center(
                  child: SizedBox(
                    width: 52,
                    child: Divider(thickness: 3, color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(permissionIcon, color: accent, size: 48),
                const SizedBox(height: 14),
                Text(
                  isVoice
                      ? 'PERMISSION · MICROPHONE'
                      : 'PERMISSION · NOTIFICATIONS',
                  style: TextStyle(
                    color: accent,
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  explainer.title,
                  style: Theme.of(modalContext).textTheme.headlineSmall
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  explainer.whyItMatters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 18),
                TemporalDivider(color: accent),
                const SizedBox(height: 18),
                Text(
                  'WHEN IT IS USED',
                  style: TextStyle(
                    color: isVoice ? AppColors.neonCyan : AppColors.neonViolet,
                    fontSize: AppSizes.fontBody,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  explainer.whenUsed,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                for (final (IconData icon, String text) in facts) ...<Widget>[
                  TemporalStatusRow(icon: icon, text: text, color: accent),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                TemporalActionButton(
                  label: explainer.primaryActionLabel,
                  icon: permissionIcon,
                  accent: accent,
                  onPressed: () async {
                    await onPrimary();
                    if (modalContext.mounted) {
                      Navigator.of(modalContext).pop();
                    }
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      onSecondary?.call();
                      Navigator.of(modalContext).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(explainer.secondaryActionLabel),
                  ),
                ),
                const SizedBox(height: 6),
                const TemporalStatusRow(
                  icon: Icons.shield_outlined,
                  text: 'Android will ask you to confirm next.',
                  color: AppColors.neonCyan,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
