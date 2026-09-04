import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
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
      final bool isSpanish = ChronoSparkLocalizations.of(
        modalContext,
      ).isSpanish;
      final _PermissionPresentation presentation = _presentationFor(
        explainer.kind,
        isSpanish: isSpanish,
      );
      return AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(modalContext).bottom,
        ),
        child: TemporalGlassSurface(
          accent: presentation.accent,
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
                Icon(presentation.icon, color: presentation.accent, size: 48),
                const SizedBox(height: 14),
                Text(
                  presentation.eyebrow,
                  style: TextStyle(
                    color: presentation.accent,
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
                TemporalDivider(color: presentation.accent),
                const SizedBox(height: 18),
                Text(
                  isSpanish ? 'CUÁNDO SE USA' : 'WHEN IT IS USED',
                  style: TextStyle(
                    color: presentation.sectionAccent,
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
                for (final (IconData icon, String text)
                    in presentation.facts) ...<Widget>[
                  TemporalStatusRow(
                    icon: icon,
                    text: text,
                    color: presentation.accent,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                TemporalActionButton(
                  label: explainer.primaryActionLabel,
                  icon: presentation.icon,
                  accent: presentation.accent,
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
                      foregroundColor: presentation.accent,
                      minimumSize: const Size.fromHeight(AppSizes.touchTarget),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(explainer.secondaryActionLabel),
                  ),
                ),
                const SizedBox(height: 6),
                TemporalStatusRow(
                  icon: Icons.shield_outlined,
                  text: isSpanish
                      ? 'Android te pedirá confirmación a continuación.'
                      : 'Android will ask you to confirm next.',
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

@immutable
class _PermissionPresentation {
  const _PermissionPresentation({
    required this.accent,
    required this.sectionAccent,
    required this.icon,
    required this.eyebrow,
    required this.facts,
  });

  final Color accent;
  final Color sectionAccent;
  final IconData icon;
  final String eyebrow;
  final List<(IconData, String)> facts;
}

_PermissionPresentation _presentationFor(
  PermissionKind kind, {
  required bool isSpanish,
}) {
  return switch (kind) {
    PermissionKind.microphone => _PermissionPresentation(
      accent: AppColors.neonViolet,
      sectionAccent: AppColors.neonCyan,
      icon: Icons.mic_none_rounded,
      eyebrow: isSpanish ? 'PERMISO · MICRÓFONO' : 'PERMISSION · MICROPHONE',
      facts: <(IconData, String)>[
        (
          Icons.touch_app_outlined,
          isSpanish
              ? 'Comienza solo después de elegir un control de micrófono'
              : 'Starts only after you choose a microphone control',
        ),
        (
          Icons.mic_off_outlined,
          isSpanish ? 'No graba en segundo plano' : 'No background recording',
        ),
        (
          Icons.volume_up_outlined,
          isSpanish
              ? 'La reproducción hablada no requiere acceso al micrófono'
              : 'Spoken playback does not require microphone access',
        ),
      ],
    ),
    PermissionKind.notifications => _PermissionPresentation(
      accent: AppColors.neonCyan,
      sectionAccent: AppColors.neonViolet,
      icon: Icons.notifications_active_outlined,
      eyebrow: isSpanish
          ? 'PERMISO · NOTIFICACIONES'
          : 'PERMISSION · NOTIFICATIONS',
      facts: <(IconData, String)>[
        (
          Icons.schedule_outlined,
          isSpanish
              ? 'Solo en los horarios que elijas'
              : 'Only at times you choose',
        ),
        (
          Icons.tune_rounded,
          isSpanish ? 'Se controla desde Ajustes' : 'Controlled from Settings',
        ),
        (
          Icons.notifications_off_outlined,
          isSpanish
              ? 'Es opcional; la aplicación funciona sin este permiso'
              : 'Optional; the app still works without it',
        ),
      ],
    ),
  };
}
