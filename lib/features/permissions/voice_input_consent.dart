import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:flutter/material.dart';

/// Remember explicit provider consent per account/device. OS microphone
/// permission remains independently checked by onStart for every session.
Future<bool> startVoiceInputWithConsent({
  required BuildContext context,
  required Future<void> Function() onStart,
  required VoiceInputConsentStore consentStore,
  bool Function()? isCurrentRequest,
}) async {
  final bool isSpanish = ChronoSparkLocalizations.of(context).isSpanish;
  final int revision = consentStore.revision;
  bool current() =>
      context.mounted &&
      consentStore.isCurrent(revision) &&
      (isCurrentRequest?.call() ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  bool accepted = await consentStore.isApproved();
  if (!context.mounted || !current()) return false;
  final PermissionExplainer disclosure = PermissionExplainers.forKind(
    PermissionKind.microphone,
    isSpanish: isSpanish,
  );
  if (!accepted) {
    await showPermissionRationaleSheet<void>(
      context: context,
      explainer: PermissionExplainer(
        kind: disclosure.kind,
        title: isSpanish
            ? 'Dictar con tu proveedor de voz'
            : 'Dictate with your speech provider',
        whyItMatters: disclosure.whyItMatters,
        whenUsed:
            '${disclosure.whenUsed}\n\n${isSpanish ? 'Recordaremos tu aprobación para esta cuenta en este dispositivo. Puedes restablecerla en Ajustes → Apariencia y permisos → Restablecer consentimiento de voz.' : 'We will remember your approval for this account on this device. Reset it in Settings → Appearance & permissions → Reset voice consent.'}',
        primaryActionLabel: isSpanish
            ? 'Aceptar y dictar'
            : 'Agree and dictate',
        secondaryActionLabel: disclosure.secondaryActionLabel,
      ),
      onPrimary: () async {
        accepted = true;
      },
    );
    if (!current() || !accepted) return false;
    await consentStore.remember(revision);
  }
  if (!current()) return false;
  await onStart();
  return true;
}
