import 'package:fantastic_guacamole/features/home/ui/models/smart_coach_exchange.dart';

class SmartCoachConversationState {
  const SmartCoachConversationState({
    this.coachingMessage,
    this.coachingPrompt,
    this.followUpError,
    this.followUps = const <SmartCoachExchange>[],
  });

  final String? coachingMessage;
  final String? coachingPrompt;
  final String? followUpError;
  final List<SmartCoachExchange> followUps;

  List<SmartCoachExchange> visibleFollowUps({int maxVisible = 20}) {
    if (followUps.length <= maxVisible) {
      return followUps;
    }
    return followUps.sublist(followUps.length - maxVisible);
  }

  List<Map<String, String>> toHistory({int maxEntries = 8}) {
    final List<Map<String, String>> history = <Map<String, String>>[];
    final String initialPrompt = coachingPrompt?.trim() ?? '';
    final String initialResponse = coachingMessage?.trim() ?? '';

    if (initialPrompt.isNotEmpty) {
      history.add(<String, String>{'role': 'user', 'content': initialPrompt});
    }

    if (initialResponse.isNotEmpty) {
      history.add(<String, String>{
        'role': 'assistant',
        'content': initialResponse,
      });
    }

    for (final SmartCoachExchange exchange in followUps) {
      history
        ..add(<String, String>{'role': 'user', 'content': exchange.question})
        ..add(<String, String>{
          'role': 'assistant',
          'content': exchange.answer,
        });
    }

    return history.length > maxEntries
        ? history.sublist(history.length - maxEntries)
        : history;
  }
}
