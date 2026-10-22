// CHRONOSPARK-CLASS: SHIPPING | Feature: Account-scoped local Chat continuity
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';

class AssistantConversationRevisionConflict extends StateError {
  AssistantConversationRevisionConflict() : super('chat_revision_changed');
}

/// Local Chat only: no draft, credit quote, voice capture, or planning packet.
class AssistantConversationHistory {
  AssistantConversationHistory({
    this.revision = 0,
    Iterable<Map<String, String>> messages = const [],
    Set<SIV2Source> sources = const {},
  }) : messages = List.unmodifiable(
         messages.map(Map<String, String>.unmodifiable),
       ),
       sources = Set.unmodifiable(sources);

  static const maxMessages = 40;
  final int revision;
  final List<Map<String, String>> messages;
  final Set<SIV2Source> sources;
}
