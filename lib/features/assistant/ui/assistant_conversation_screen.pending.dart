part of 'assistant_conversation_screen.dart';

/// A confirmed paid request that outlived its screen is collected here when
/// the person comes back: joined if it is still running since the app started,
/// or re-sent with the same id and signed quote, which the server answers from
/// its reply cache without a second reservation (or, while the first call is
/// still running, with `request_reserved`: see [_collectAgainLater]).
extension _PendingRequest on _AssistantConversationScreenState {
  String get _stillAnsweringText => copy(
    'Your reply is still on its way: the first attempt of this same request is still being answered. It is collected again here in a few seconds, and nothing more is charged for collecting it. Your question is kept.',
    'Tu respuesta sigue en camino: el primer intento de esta misma solicitud aún se está respondiendo. Se vuelve a recoger aquí en unos segundos y no se cobra nada más por recogerla. Tu pregunta se conserva.',
  );

  /// The server is still answering the first call of this same request id.
  /// The request stays stored and is collected again with the same id after a
  /// short wait, until it can no longer be collected; then the expired text is
  /// shown. Nothing is reported to the free side: this is not an outcome.
  void _collectAgainLater(ConversationQuote quote, {required bool recovered}) {
    final id = quote.packet.requestId;
    final generation = _generation;
    _reservedRetry?.cancel();
    _updateHistory(() {
      _error = _stillAnsweringText;
      _outOfCredits = false;
    });
    _reservedRetry = Timer(
      ref.read(conversationReservedRetryIntervalProvider),
      () {
        _reservedRetry = null;
        if (!mounted ||
            generation != _generation ||
            _busy ||
            _pending?.packet.requestId != id) {
          return;
        }
        final deadline = _pendingCollectBefore ?? quote.expiresAt;
        final now = ref.read(conversationClockProvider)().toUtc();
        if (!deadline.isAfter(now)) {
          ref
              .read(conversationExecutionRegistryProvider)
              .finish(id, shown: true);
          _forgetPending(id);
          _updateHistory(() {
            _pending = null;
            if (_input.text.trim().isEmpty) {
              _input.text = quote.packet.toJson()['prompt'] as String;
            }
          });
          _showFailure(_pendingExpiredText(questionRestored: true));
          return;
        }
        if (recovered) _recoveringRequestId = id;
        unawaited(_send(retry: true));
      },
    );
  }

  /// [questionRestored] is false when only a content-free marker was left.
  String _pendingExpiredText({required bool questionRestored}) =>
      questionRestored
      ? copy(
          'An earlier AI request was still finishing when you left, and its reply can no longer be collected. It may have used credits; check your balance. Your question is back in the box below; start a new request to ask again.',
          'Una solicitud de IA anterior seguía en curso cuando saliste y ya no se puede recuperar su respuesta. Es posible que haya usado créditos; revisa tu saldo. Tu pregunta está de nuevo en el cuadro de abajo; inicia una solicitud nueva para preguntar otra vez.',
        )
      : copy(
          'An earlier AI request was still finishing when you left, and its reply can no longer be collected. It may have used credits; check your balance. Start a new request to ask again.',
          'Una solicitud de IA anterior seguía en curso cuando saliste y ya no se puede recuperar su respuesta. Es posible que haya usado créditos; revisa tu saldo. Inicia una solicitud nueva para preguntar otra vez.',
        );

  String get _pendingUnreadableText => copy(
    'An earlier AI request could not be restored on this device, so it was not sent again. It may have used credits; check your balance. Start a new request to ask again.',
    'No se pudo restaurar en este dispositivo una solicitud de IA anterior, así que no se volvió a enviar. Es posible que haya usado créditos; revisa tu saldo. Inicia una solicitud nueva para preguntar otra vez.',
  );

  /// Choose a step keeps no Chat history, so it reads only its stored
  /// request; damaged Chat data does not stop that.
  Future<void> _loadPlannerPending() async {
    if (widget.surface != ConversationSurface.planner) return;
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    final registry = ref.read(conversationExecutionRegistryProvider);
    final generation = _generation;
    final AssistantConversationHistory saved;
    try {
      saved = await repository.loadPending(keep: registry.isRunning);
    } on Object {
      // Storage unreadable as a whole: a new request is refused with advice.
      return;
    }
    if (!mounted || generation != _generation) return;
    await _resumePending(saved);
  }

  Future<void> _resumePending(AssistantConversationHistory saved) async {
    if (!mounted) return;
    final surface = widget.surface;
    final generation = _generation;
    final scope = ref.read(accountStorageScopeProvider).v2Namespace;
    final authGeneration = ref.read(authSessionBoundaryProvider).generation;
    bool sameAccount() =>
        mounted &&
        generation == _generation &&
        ref.read(accountStorageScopeProvider).v2Namespace == scope &&
        ref.read(authSessionBoundaryProvider).generation == authGeneration;
    final registry = ref.read(conversationExecutionRegistryProvider);
    // Any stored request still collectable, on either surface, has its
    // content removed at its collect-by time even if no screen is open then.
    final now = ref.read(conversationClockProvider)();
    for (final stored in saved.pendingRequests.values) {
      if (!stored.isExpired(now)) registry.schedulePurge(stored.collectBefore);
    }
    final pending = saved.pendingRequests[surface];
    if (pending == null) {
      final expiredId = saved.expiredPendingRequests[surface];
      if (expiredId != null) {
        registry.finish(expiredId, shown: true);
        _forgetPending(expiredId);
        _showFailure(_pendingExpiredText(questionRestored: false));
      } else if (saved.unreadablePendingRequests.contains(surface)) {
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
    if (scope == null || pending.quote.packet.accountScope != scope) {
      _forgetPending(id);
      _showFailure(_pendingUnreadableText);
      return;
    }
    // A run still going since the app started is joined even after the
    // quote's lifetime; it needs no new server call. Checked before the busy
    // return so the question is put back even while another request runs.
    if (pending.isExpired(now) && !registry.isRunning(id)) {
      registry.finish(id, shown: true);
      _forgetPending(id);
      _updateHistory(() {
        if (_input.text.trim().isEmpty) _input.text = pending.prompt;
      });
      _showFailure(_pendingExpiredText(questionRestored: true));
      return;
    }
    if (_busy || _pending != null) return;
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
    // The account may have changed while waiting. That account's request
    // stays in its own store and is never sent from here.
    if (!sameAccount() || _busy || _pending != null) return;
    _updateHistory(() {
      _pending = pending.quote;
      _pendingCollectBefore = pending.collectBefore;
      _recoveringRequestId = id;
      // Every outcome text says the question is kept; make that true.
      if (_input.text.trim().isEmpty) _input.text = pending.prompt;
    });
    await _send(retry: true);
  }

  String get _stoppedBeforeSendingText => copy(
    'Stopped before the request was sent for a reply. Nothing was charged. Your question is retained.',
    'Se detuvo antes de enviar la solicitud para obtener una respuesta. No se cobró nada. Tu pregunta se conserva.',
  );

  /// Reads storage back for [record] after saving reported an error once the
  /// write was handed over: true when it is stored, false when it is not,
  /// null when that cannot be read.
  Future<bool?> _storedRequest(PendingConversationRequest record) async {
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return null;
    final registry = ref.read(conversationExecutionRegistryProvider);
    try {
      final saved = await repository.loadPending(keep: registry.isRunning);
      return saved.pendingRequests[record.surface]?.requestId ==
          record.requestId;
    } on Object {
      return null;
    }
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
