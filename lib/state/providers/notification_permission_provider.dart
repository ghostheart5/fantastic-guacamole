import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/data/storage/shared_prefs_service.dart';
import 'package:fantastic_guacamole/state/providers/account_operation.dart';
import 'package:fantastic_guacamole/state/providers/account_scoped_store_provider.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/repository_providers.dart';
import 'package:fantastic_guacamole/state/providers/settings_ui_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How this account last answered a request for notification permission.
enum NotificationPermissionRefusal {
  /// Said "Not now" to the explanation; the system was never asked.
  declined,

  /// The system dialog was refused. The system may not show it again, so a
  /// later explicit request goes to device settings instead.
  denied,
}

@immutable
class NotificationPermissionMemory {
  const NotificationPermissionMemory({
    this.refusal,
    this.noticeDismissed = false,
  });

  final NotificationPermissionRefusal? refusal;

  /// The "notifications are off" notice was closed for this account.
  final bool noticeDismissed;
}

/// Whether this platform has a notification permission the app can request.
final notificationPermissionSupportedProvider = Provider<bool>(
  (Ref ref) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS),
);

final notificationPermissionProvider =
    NotifierProvider<
      NotificationPermissionController,
      NotificationPermissionMemory
    >(NotificationPermissionController.new);

/// The account-scoped memory and steps behind the in-context permission
/// request. The request itself is shown by the feature-level helper.
class NotificationPermissionController
    extends Notifier<NotificationPermissionMemory> {
  static const String refusalKey = 'notification_permission_refusal_v1';
  static const String noticeDismissedKey =
      'notification_permission_notice_dismissed_v1';

  @override
  NotificationPermissionMemory build() {
    // Without a writable account there is nothing to remember (or remind).
    if (!ref.watch(accountStorageScopeProvider).isWritable) {
      return const NotificationPermissionMemory();
    }
    return _memory(ref.watch(accountSharedPrefsStoreProvider));
  }

  static NotificationPermissionMemory _memory(SharedPrefsStore store) {
    return NotificationPermissionMemory(
      refusal: switch (store.load(refusalKey)) {
        'declined' => NotificationPermissionRefusal.declined,
        'denied' => NotificationPermissionRefusal.denied,
        _ => null,
      },
      noticeDismissed: store.load(noticeDismissedKey) == 'true',
    );
  }

  bool get supported => ref.read(notificationPermissionSupportedProvider);

  NotificationPermissionRefusal? get refusal => state.refusal;

  /// Whether any reminder switch of this account is on.
  bool anyReminderSwitchOn() {
    if (!ref.read(accountStorageScopeProvider).isWritable) return false;
    final SettingsUiActions actions = ref.read(settingsUiActionsProvider);
    final prefs = actions.loadAdvancedReminderPrefs();
    return prefs.goalRemindersEnabled ||
        prefs.habitRemindersEnabled ||
        prefs.dailyPlanningEnabled ||
        actions.loadReflectionReminderPrefs().enabled;
  }

  /// Reads the system permission without asking for it.
  Future<bool> isGranted() async {
    final AccountOperation owner = AccountOperation.capture(ref);
    final bool granted;
    try {
      granted = await ref
          .read(notificationSchedulerProvider)
          .init(requestPermissions: false);
    } on Object catch (error) {
      Logger.warn('Notification permission could not be read ($error).');
      return false;
    }
    if (granted && owner.isCurrent) await _forgetRefusal();
    return granted;
  }

  /// Shows the system dialog through [via], or the plain local request.
  /// A grant rebuilds reminders through the existing reconcile.
  Future<bool> request({Future<bool> Function()? via}) async {
    final AccountOperation owner = AccountOperation.capture(ref);
    final SettingsUiActions actions = ref.read(settingsUiActionsProvider);
    bool granted;
    try {
      granted = await (via ?? actions.requestNotificationPermission)();
    } on Object catch (error) {
      Logger.warn('Notification permission request failed ($error).');
      granted = false;
    }
    if (!owner.isCurrent) return granted;
    if (!granted) {
      await _write(refusalKey, 'denied');
      return false;
    }
    await _forgetRefusal();
    try {
      await actions.refreshNotificationPermissionAndReminders();
    } on Object catch (error) {
      Logger.warn('Reminders could not be rebuilt after a grant ($error).');
    }
    return true;
  }

  /// "Not now" on the explanation. A system refusal is kept as it is.
  Future<void> recordDeclined() async {
    if (state.refusal != null) return;
    await _write(refusalKey, 'declined');
  }

  Future<void> dismissNotice() => _write(noticeDismissedKey, 'true');

  Future<void> _forgetRefusal() async {
    if (state.refusal == null && !state.noticeDismissed) return;
    final AccountOperation owner = AccountOperation.capture(ref);
    final SharedPrefsStore store = ref.read(accountSharedPrefsStoreProvider);
    await store.delete(refusalKey);
    await store.delete(noticeDismissedKey);
    if (owner.isCurrent) state = const NotificationPermissionMemory();
  }

  Future<void> _write(String key, String value) async {
    final AccountOperation owner = AccountOperation.capture(ref);
    if (!owner.isCurrent) return;
    await ref.read(accountSharedPrefsStoreProvider).save(key, value);
    if (!owner.isCurrent) return;
    state = _memory(ref.read(accountSharedPrefsStoreProvider));
  }
}
