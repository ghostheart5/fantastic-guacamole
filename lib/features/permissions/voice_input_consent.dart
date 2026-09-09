import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/material.dart';

/// Review device-provider processing before each dictation, including when the
/// OS permission was granted earlier. Dismissal never starts audio capture.
Future<bool> startVoiceInputWithConsent({
  required BuildContext context,
  required Future<void> Function() onStart,
  bool Function()? isCurrentRequest,
}) async {
  final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
  bool accepted = false;
  final PermissionExplainer disclosure = PermissionExplainers.forKind(
    PermissionKind.microphone,
    isSpanish: isSpanish,
  );
  await showPermissionRationaleSheet<void>(
    context: context,
    explainer: PermissionExplainer(
      kind: disclosure.kind,
      title: isSpanish
          ? 'Dictar con tu proveedor de voz'
          : 'Dictate with your speech provider',
      whyItMatters: disclosure.whyItMatters,
      whenUsed: disclosure.whenUsed,
      primaryActionLabel: isSpanish ? 'Aceptar y dictar' : 'Agree and dictate',
      secondaryActionLabel: disclosure.secondaryActionLabel,
    ),
    onPrimary: () async {
      accepted = true;
    },
  );
  if (!context.mounted || !accepted || !(isCurrentRequest?.call() ?? true)) {
    return false;
  }
  final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
  if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return false;
  await onStart();
  return true;
}
