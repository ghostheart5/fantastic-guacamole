import 'package:fantastic_guacamole/engine/si/si_ai_service.dart';
import 'package:fantastic_guacamole/features/coach/models/chat_message.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final siAiServiceProvider = Provider<SIAIService>((ref) {
  return const SIAIService();
});

final chatProvider = NotifierProvider<ChatController, List<ChatMessage>>(
  ChatController.new,
);

class ChatController extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    _init();
    return <ChatMessage>[];
  }

  Future<void> _init() async {
    final tasks = await ref.read(tasksProvider.future);
    final si = ref.read(siStateProvider);
    final learning = ref.read(learningProvider);
    final personality = ref.read(aiPersonalityProvider);

    final response = ref
        .read(siAiServiceProvider)
        .generate(
          tasks: tasks,
          si: si,
          learning: learning,
          personality: personality,
        );

    _push(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: ChatAuthor.coach,
        text: response.message,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> sendMessage(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;

    _push(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: ChatAuthor.user,
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    );

    final tasks = await ref.read(tasksProvider.future);
    final energy = ref.read(energyProvider);
    final learning = ref.read(learningProvider);
    final personality = ref.read(aiPersonalityProvider);

    final response = ref
        .read(siAiServiceProvider)
        .handleInput(
          trimmed,
          tasks: tasks,
          energy: energy,
          learning: learning,
          personality: personality,
        );

    _push(
      ChatMessage(
        id: (DateTime.now().microsecondsSinceEpoch + 1).toString(),
        author: ChatAuthor.coach,
        text: response.message,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _push(ChatMessage message) => state = [...state, message];
}
