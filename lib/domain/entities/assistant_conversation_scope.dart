enum AssistantSurface {
  smartPlanner('smart_planner'),
  siConsole('si_console');

  const AssistantSurface(this.storageId);

  final String storageId;
}

/// Identifies one assistant conversation independently of account identity.
///
/// Account identity is added by the account-scoped repository. Keeping the
/// surface and conversation together prevents a caller from reading or
/// writing an unqualified assistant state record.
final class AssistantConversationScope {
  const AssistantConversationScope({
    required this.surface,
    required this.conversationId,
  }) : assert(conversationId != '');

  final AssistantSurface surface;
  final String conversationId;

  static const AssistantConversationScope primarySmartPlanner =
      AssistantConversationScope(
        surface: AssistantSurface.smartPlanner,
        conversationId: 'primary',
      );

  static const AssistantConversationScope primarySiConsole =
      AssistantConversationScope(
        surface: AssistantSurface.siConsole,
        conversationId: 'primary',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssistantConversationScope &&
          other.surface == surface &&
          other.conversationId == conversationId;

  @override
  int get hashCode => Object.hash(surface, conversationId);
}
