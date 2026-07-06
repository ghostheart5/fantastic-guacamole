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
        'Voice input and playback reduce friction so you can interact hands-free during planning and coaching.',
    whenUsed:
        'Used only when you tap voice actions. Audio is not captured unless you explicitly start voice input.',
    primaryActionLabel: 'Allow Microphone',
  );
}
