import 'package:fantastic_guacamole/domain/entities/assistant_conversation.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which of the two ways to use Chat and Choose a step the person picked:
/// the free on-device assistant or AI chat. Holds only a choice, never text or
/// replies, and starts again for another account. It lives as long as the app
/// runs, so the choice survives leaving a screen and coming back.
class AssistantChatModeController extends Notifier<Set<ConversationSurface>> {
  @override
  Set<ConversationSurface> build() {
    ref.watch(accountStorageScopeProvider.select((scope) => scope.v2Namespace));
    return const <ConversationSurface>{};
  }

  /// The state holds the surfaces on the free on-device assistant. Any other
  /// surface is on AI chat, which is the default.
  void choose(ConversationSurface surface, {required bool onDevice}) {
    if (state.contains(surface) == onDevice) return;
    state = onDevice
        ? <ConversationSurface>{...state, surface}
        : (<ConversationSurface>{...state}..remove(surface));
  }
}

final assistantChatModeProvider =
    NotifierProvider<AssistantChatModeController, Set<ConversationSurface>>(
      AssistantChatModeController.new,
    );

/// True while [surface] is on the free on-device assistant.
final assistantOnDeviceModeProvider =
    Provider.family<bool, ConversationSurface>(
      (ref, surface) => ref.watch(
        assistantChatModeProvider.select((modes) => modes.contains(surface)),
      ),
    );
