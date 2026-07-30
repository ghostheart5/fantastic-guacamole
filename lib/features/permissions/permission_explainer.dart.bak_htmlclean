import 'package:flutter/foundation.dart';

@immutable
class PermissionExplainer {
  const PermissionExplainer({
    required this.title,
    required this.whyItMatters,
    required this.whenUsed,
    required this.primaryActionLabel,
    this.secondaryActionLabel = 'Not Now',
  });

  final String title;
  final String whyItMatters;
  final String whenUsed;
  final String primaryActionLabel;
  final String secondaryActionLabel;
}

class PermissionExplainers {
  const PermissionExplainers._();

  static const PermissionExplainer notification = PermissionExplainer(
    title: 'Enable Notifications',
    whyItMatters:
        'Notifications help you keep momentum by surfacing reflection and focus reminders at the right time.',
    whenUsed:
        'Used only for reminders you configure in app settings. You can disable them any time.',
    primaryActionLabel: 'Allow Notifications',
  );

  static const PermissionExplainer voice = PermissionExplainer(
    title: 'Enable Voice Access',
    whyItMatters:
        'Voice input and spoken responses let you capture thoughts hands-free in coaching and the SI console.',
    whenUsed:
        'Used only when you tap a microphone or voice playback control. Audio is never captured during normal planning or background use.',
    primaryActionLabel: 'Allow Microphone',
  );
}
