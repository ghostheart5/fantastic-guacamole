import 'package:fantastic_guacamole/features/permissions/notification_permission_prompt.dart';
import 'package:fantastic_guacamole/features/permissions/permission_explainer.dart';
import 'package:fantastic_guacamole/features/permissions/permission_rationale_sheet.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/providers/notification_permission_provider.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:fantastic_guacamole/state/providers/reminders_off_hint_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks for notification permission at the moment something that can remind
/// the person is saved or switched on. Call it after the item is saved, so
/// saving is never held up by the question.
///
/// Never asks when notifications are already allowed, and always shows the
/// explanation before the system dialog. After this account said no (to the
/// explanation or to the system) it does not ask again by itself; pass
/// [userInitiated] for an explicit "turn on notifications" action. Returns whether
/// notifications are allowed afterwards.
///
/// Pass [afterSave] when something with a reminder was just saved: if the
/// account already refused, the guide then says once, on this screen, where
/// to turn notifications on.
Future<bool> ensureNotificationPermission(
  BuildContext context,
  WidgetRef ref, {
  bool userInitiated = false,
  bool afterSave = false,
}) async {
  final NotificationPermissionController permission = ref.read(
    notificationPermissionProvider.notifier,
  );
  if (!permission.supported) return false;
  if (await permission.isGranted()) return true;
  if (!context.mounted) return false;
  if (!userInitiated &&
      ref.read(notificationPermissionProvider).refusal != null) {
    if (afterSave) {
      ref
          .read(remindersOffHintRequestsProvider.notifier)
          .reminderSavedWhileOff();
    }
    return false;
  }
  bool? granted;
  await showPermissionRationaleSheet<void>(
    context: context,
    explainer: PermissionExplainers.forKind(
      PermissionKind.notifications,
      isSpanish: ChronoSparkLocalizations.of(context).isSpanish,
    ),
    onPrimary: () async {
      granted = await permission.request();
    },
  );
  if (granted == null) await permission.recordDeclined();
  return granted ?? false;
}

/// An explicit "Turn on notifications": asks in context, or opens device
/// settings once the system has refused (it may no longer show its dialog).
Future<void> turnOnNotifications(BuildContext context, WidgetRef ref) async {
  if (ref.read(notificationPermissionProvider).refusal ==
      NotificationPermissionRefusal.denied) {
    await openNotificationSystemSettings(context, ref);
    return;
  }
  await ensureNotificationPermission(context, ref, userInitiated: true);
}

/// The Settings card: the manual route, so it asks even after a refusal.
/// It asks only for the local notification permission.
class NotificationPermissionSettingsCard extends ConsumerWidget {
  const NotificationPermissionSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueListenableBuilder<bool?>(
      valueListenable: ref.watch(notificationPermissionListenableProvider),
      builder: (BuildContext context, bool? granted, _) =>
          NotificationPermissionPrompt(
            permissionGranted: granted,
            explainsFirst: false,
            onRequestPermission: () =>
                ensureNotificationPermission(context, ref, userInitiated: true),
            onOpenSystemSettings: () =>
                openNotificationSystemSettings(context, ref),
          ),
    );
  }
}

/// Opens this app's page in device settings, or says where to go.
Future<void> openNotificationSystemSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  final bool opened = await ref
      .read(settingsUiActionsProvider)
      .openSystemAppSettings();
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        journeyText(
          context,
          'Open your device app settings and enable notifications for Axiomara.',
          'Abre los ajustes de aplicaciones del dispositivo y activa las notificaciones para Axiomara.',
        ),
      ),
    ),
  );
}
