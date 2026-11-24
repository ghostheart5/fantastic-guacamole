// CHRONOSPARK-CLASS: SHIPPING | Feature: Account-scoped local Chat continuity
import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

class AssistantConversationRevisionConflict extends StateError {
  AssistantConversationRevisionConflict() : super('chat_revision_changed');
}

/// Local Chat: published pairs and source choices, never a draft or voice
/// capture. A confirmed paid request is kept only while it is still running
/// and can be collected ([pendingRequests], at most one per surface).
class AssistantConversationHistory {
  AssistantConversationHistory({
    this.revision = 0,
    Iterable<Map<String, String>> messages = const [],
    Set<SIV2Source> sources = const {},
    Map<ConversationSurface, PendingConversationRequest> pendingRequests =
        const {},
    Set<ConversationSurface> unreadablePendingRequests = const {},
  }) : messages = List.unmodifiable(
         messages.map(Map<String, String>.unmodifiable),
       ),
       sources = Set.unmodifiable(sources),
       pendingRequests = Map.unmodifiable(pendingRequests),
       unreadablePendingRequests = Set.unmodifiable(unreadablePendingRequests);

  static const maxMessages = 40;
  final int revision;
  final List<Map<String, String>> messages;
  final Set<SIV2Source> sources;
  final Map<ConversationSurface, PendingConversationRequest> pendingRequests;

  /// Surfaces whose stored paid request cannot be rebuilt byte for byte.
  final Set<ConversationSurface> unreadablePendingRequests;
}
