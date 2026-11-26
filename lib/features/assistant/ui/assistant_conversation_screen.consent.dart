part of 'assistant_conversation_screen.dart';

/// Turning on AI chat from inside the conversation. The screen is shown only
/// when the build can do AI chat (assistantConversationSurfaceAvailableProvider),
/// so this offer never appears in a build without it.
extension _AiChatConsent on _AssistantConversationScreenState {
  /// Opens the consent sheet. Allow saves the existing per-account
  /// externalAiAllowed preference; Not now changes nothing. Nothing is sent.
  Future<void> _turnOnAiChat() async {
    if (_busy) return;
    final scope = ref.read(accountStorageScopeProvider).v2Namespace;
    final authGeneration = ref.read(authSessionBoundaryProvider).generation;
    final generation = _generation;
    if (scope == null) return;
    final allowed = await showAiChatConsentSheet(
      context,
      onRoute: (sheet) {
        _dialogContext = sheet;
        _dialogRoute = sheet == null ? null : ModalRoute.of(sheet);
      },
    );
    // The choice belongs to the account that saw the sheet. If the account
    // changed meanwhile, the sheet was closed and nothing is saved.
    if (!allowed ||
        !mounted ||
        generation != _generation ||
        ref.read(accountStorageScopeProvider).v2Namespace != scope ||
        ref.read(authSessionBoundaryProvider).generation != authGeneration) {
      return;
    }
    // Waits for the stored profile, so the person's other choices are kept;
    // writes nothing if the account changes while it waits.
    try {
      await ref
          .read(personalizationProfileProvider.notifier)
          .setExternalAiAllowed(true);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy(
              'AI chat could not be turned on. Please try again.',
              'No se pudo activar el chat con IA. Inténtalo de nuevo.',
            ),
          ),
        ),
      );
    }
  }

  Widget _aiChatOffNotice() => Container(
    key: const Key('conversation-ai-off-notice'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF2A1F05),
      border: Border.all(color: Colors.amberAccent),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.amberAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                copy('AI chat is off', 'El chat con IA está desactivado'),
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          copy(
            'Turn it on to type here. You will see what is sent, to whom and what it costs first. Each message shows its credit price before anything is charged.',
            'Actívalo para escribir aquí. Primero verás qué se envía, a quién y cuánto cuesta. Cada mensaje muestra su precio en créditos antes de cobrar algo.',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('conversation-ai-off-turn-on'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _busy || !widget.isActive ? null : _turnOnAiChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(copy('Turn on AI chat', 'Activar el chat con IA')),
        ),
      ],
    ),
  );
}
