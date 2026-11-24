part of 'assistant_conversation_screen.dart';

/// A confirmed paid request that outlived its screen is collected here when
/// the person comes back: joined if it is still running since the app started, or
/// re-sent with the same id and signed quote, which the server answers from
/// its reply cache without a second reservation.
extension _PendingRequest on _AssistantConversationScreenState {
  String get _pendingExpiredText => copy(
    'An earlier AI request was still finishing when you left, and its reply can no longer be collected. It may have used credits; check your balance. Your question is back in the box below; start a new request to ask again.',
    'Una solicitud de IA anterior seguía en curso cuando saliste y ya no se puede recuperar su respuesta. Es posible que haya usado créditos; revisa tu saldo. Tu pregunta está de nuevo en el cuadro de abajo; inicia una solicitud nueva para preguntar otra vez.',
  );

  String get _pendingUnreadableText => copy(
    'An earlier AI request could not be restored on this device, so it was not sent again. It may have used credits; check your balance. Start a new request to ask again.',
    'No se pudo restaurar en este dispositivo una solicitud de IA anterior, así que no se volvió a enviar. Es posible que haya usado créditos; revisa tu saldo. Inicia una solicitud nueva para preguntar otra vez.',
  );

  /// Choose a step keeps no Chat history, so it reads only its stored request.
  Future<void> _loadPlannerPending() async {
    if (widget.surface != ConversationSurface.planner) return;
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    final generation = _generation;
    final AssistantConversationHistory saved;
    try {
      saved = await repository.load();
    } on Object {
      // Unreadable Chat storage: a new request cannot be stored either, so
      // sending stays blocked with an explanation until Chat is cleared.
      return;
    }
    if (!mounted || generation != _generation) return;
    await _resumePending(saved);
  }

  Future<void> _resumePending(AssistantConversationHistory saved) async {
    if (!mounted) return;
    final surface = widget.surface;
    final registry = ref.read(conversationExecutionRegistryProvider);
    final pending = saved.pendingRequests[surface];
    if (pending == null) {
      if (saved.unreadablePendingRequests.contains(surface)) {
        _forgetPending(null);
        _showFailure(_pendingUnreadableText);
      }
      return;
    }
    final id = pending.requestId;
    if (registry.wasShown(id)) {
      _forgetPending(id);
      return;
    }
    if (pending.quote.packet.accountScope !=
        ref.read(accountStorageScopeProvider).v2Namespace) {
      _forgetPending(id);
      _showFailure(_pendingUnreadableText);
      return;
    }
    if (_busy || _pending != null) return;
    // A run still going since the app started is joined even after the quote's
    // lifetime; it needs no new server call.
    if (pending.isExpired(DateTime.now()) && !registry.isRunning(id)) {
      registry.finish(id, shown: true);
      _forgetPending(id);
      _updateHistory(() {
        if (_input.text.trim().isEmpty) _input.text = pending.prompt;
      });
      _showFailure(_pendingExpiredText);
      return;
    }
    // After an app restart the release decisions may still be loading; a new
    // request waits for them too (ConversationPacketFactory.build).
    try {
      await Future.wait([
        for (final capability in [
          surface == ConversationSurface.planner
              ? AssistantReleaseCapability.smartPlannerV2
              : AssistantReleaseCapability.siConsoleV2,
          AssistantReleaseCapability.safetyCritic,
        ])
          ref.read(assistantReleaseDecisionProvider(capability).future),
      ]);
    } on Object {
      // The send below then fails closed and keeps Retry same request.
    }
    if (!mounted || _busy || _pending != null) return;
    _updateHistory(() {
      _pending = pending.quote;
      _recoveringRequestId = id;
    });
    await _send(retry: true);
  }

  /// Removes this surface's stored request; null removes an unreadable one.
  void _forgetPending(String? requestId) {
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    final surface = widget.surface;
    unawaited(() async {
      try {
        await repository.clearPending(surface, requestId: requestId);
      } on Object {
        // The registry still records the outcome as shown while the app runs.
      }
    }());
  }
}
