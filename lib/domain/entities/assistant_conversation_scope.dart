enum AssistantSurface {
  smartPlanner('smart_planner'),
  siConsole('si_console');

  const AssistantSurface(this.storageId);

  final String storageId;

  static AssistantSurface fromStorageId(String value) {
    for (final AssistantSurface surface in values) {
      if (surface.storageId == value) return surface;
    }
    throw FormatException('Unknown assistant surface: $value.');
  }
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

  void validate() {
    if (conversationId.trim().isEmpty ||
        conversationId != conversationId.trim()) {
      throw const FormatException(
        'Assistant conversation ids must be non-empty and normalized.',
      );
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'surfaceId': surface.storageId,
    'conversationId': conversationId,
  };

  factory AssistantConversationScope.fromJson(Map<String, Object?> json) {
    if (json.keys.toSet().difference(const <String>{
          'surfaceId',
          'conversationId',
        }).isNotEmpty ||
        !json.containsKey('surfaceId') ||
        !json.containsKey('conversationId')) {
      throw const FormatException('Invalid assistant conversation scope.');
    }
    final Object? rawSurface = json['surfaceId'];
    final Object? rawConversation = json['conversationId'];
    if (rawSurface is! String || rawConversation is! String) {
      throw const FormatException('Invalid assistant conversation identity.');
    }
    final AssistantConversationScope scope = AssistantConversationScope(
      surface: AssistantSurface.fromStorageId(rawSurface),
      conversationId: rawConversation,
    );
    scope.validate();
    return scope;
  }

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
