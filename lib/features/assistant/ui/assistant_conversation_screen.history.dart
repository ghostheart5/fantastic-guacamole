part of 'assistant_conversation_screen.dart';

extension _StoredChat on _AssistantConversationScreenState {
  void _restartChat() {
    if (widget.surface != ConversationSurface.si) return;
    _updateHistory(() {
      _historyEpoch++;
      _generation++;
      _history.clear();
      _input.clear();
      _pending = null;
      _busy = false;
      _waitIndicatorDismissed = false;
      _error = null;
      _outOfCredits = false;
      _filter.clear();
      _scenario.clear();
      _intent = SIV2Intent.answer;
      _range = SIV2TimeRange.all;
      // Nothing until this account's saved choice or default has loaded.
      _sources = <SIV2Source>{};
      _extras = <ConversationExtraSource>{};
      _sourcesChosen = false;
      _scopeExplained = false;
      _scopeNoticeVisible = false;
      _attachedTaskId = null;
      _energy = null;
      _historyReady = false;
      _historyLoading = true;
      _historySaveFailed = false;
      _historyConflict = false;
      _historyClearFailed = false;
      _storedHistoryRevision = 0;
    });
    unawaited(_loadChat());
  }

  Future<void> _loadChat() async {
    final epoch = ++_historyEpoch;
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    _updateHistory(() => _historyLoading = true);
    AssistantConversationHistory? loaded;
    try {
      if (repository == null) throw StateError('chat_account_unavailable');
      final saved = await repository.load(
        keep: ref.read(conversationExecutionRegistryProvider).isRunning,
      );
      if (!mounted || epoch != _historyEpoch) return;
      loaded = saved;
      _updateHistory(() {
        _history
          ..clear()
          ..addAll(saved.messages);
        _applySavedScope(saved);
        _storedHistoryRevision = saved.revision;
        _historyReady = true;
        _historySaveFailed = false;
        _historyConflict = false;
        _historyClearFailed = false;
      });
    } on Object {
      if (!mounted || epoch != _historyEpoch) return;
      _updateHistory(() {
        _historyReady = false;
        _sources = <SIV2Source>{};
        _extras = <ConversationExtraSource>{};
        _sourcesChosen = false;
        // Unknown for this account, so a later Clear shows the line.
        _scopeExplained = false;
        _scopeNoticeVisible = false;
      });
    } finally {
      if (mounted && epoch == _historyEpoch) {
        _updateHistory(() => _historyLoading = false);
      }
    }
    if (loaded != null && mounted && epoch == _historyEpoch) {
      await _resumePending(loaded);
    }
  }

  // Snapshot only published pairs and source consent. Never persist an input
  // draft, task attachment, or response that safety withheld. The confirmed
  // request whose reply this publishes is removed in the same write.
  void _persistChat({String? completedRequestId}) {
    if (widget.surface != ConversationSurface.si ||
        !_historyReady ||
        _historyConflict) {
      if (completedRequestId != null) _forgetPending(completedRequestId);
      return;
    }
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    final epoch = _historyEpoch;
    final messages = _history
        .map((turn) => Map<String, String>.of(turn))
        .toList();
    final sources = _sources.toSet();
    final sourcesChosen = _sourcesChosen;
    _historyWriteTail = _historyWriteTail.then((_) async {
      Future<void> clearCompleted() async {
        if (completedRequestId == null) return;
        try {
          await repository.clearPending(
            ConversationSurface.si,
            requestId: completedRequestId,
          );
        } on Object {
          // The registry still records the reply as shown while the app runs.
        }
      }

      if (epoch != _historyEpoch || _historyConflict) {
        await clearCompleted();
        return;
      }
      try {
        final revision = await repository.save(
          expectedRevision: _storedHistoryRevision,
          messages: messages,
          sources: sources,
          sourcesChosen: sourcesChosen,
          completedRequestId: completedRequestId,
        );
        if (epoch != _historyEpoch) return;
        _storedHistoryRevision = revision;
        if (mounted) _updateHistory(() => _historySaveFailed = false);
      } on AssistantConversationRevisionConflict {
        await clearCompleted();
        if (!mounted || epoch != _historyEpoch) return;
        _updateHistory(() {
          _historyConflict = true;
          _historySaveFailed = false;
        });
      } on Object {
        // A local write failure must never retry an already paid AI request.
        await clearCompleted();
        if (!mounted || epoch != _historyEpoch) return;
        _updateHistory(() => _historySaveFailed = true);
      }
    });
  }

  Future<void> _clearChat() async {
    final epoch = _historyEpoch;
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    // A paid request kept here (still finishing after the wait limit, or
    // waiting for Retry same request) is removed too: say so.
    final keptRequest = _pending != null
        ? ' ${copy('A paid request from this conversation is still kept, and its reply may still be on its way. Clearing also removes it: its reply will not be shown, and it may have used credits.', 'Todavía se conserva una solicitud pagada de esta conversación y su respuesta puede seguir en camino. Borrar también la elimina: su respuesta no se mostrará y es posible que haya usado créditos.')}'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy('Clear conversation?', '¿Borrar la conversación?')),
        content: Text(
          copy(
                'Delete this Chat history from this account on this device? AI chat goes back to using My plan. This cannot be undone. Tasks, goals, and habits stay saved.',
                '¿Borrar el historial de Chat de esta cuenta en este dispositivo? El chat con IA vuelve a usar Mi plan. No se puede deshacer. Se conservan las tareas, metas y hábitos.',
              ) +
              keptRequest,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy('Cancel', 'Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy('Clear conversation', 'Borrar conversación')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || epoch != _historyEpoch) return;
    final clearEpoch = ++_historyEpoch;
    _updateHistory(() {
      _historyLoading = true;
      _historyClearFailed = false;
    });
    try {
      await _historyWriteTail;
      final revision = await repository.clear();
      if (!mounted || clearEpoch != _historyEpoch) return;
      _updateHistory(() {
        _history.clear();
        _applyDefaultScope();
        _input.clear();
        _pending = null;
        _filter.clear();
        _scenario.clear();
        _attachedTaskId = null;
        _energy = null;
        _generation++;
        _storedHistoryRevision = revision;
        _historyReady = true;
        _historySaveFailed = false;
        _historyConflict = false;
        _historyClearFailed = false;
      });
    } on Object {
      if (mounted && clearEpoch == _historyEpoch) {
        _updateHistory(() => _historyClearFailed = true);
      }
    } finally {
      if (mounted && clearEpoch == _historyEpoch) {
        _updateHistory(() => _historyLoading = false);
      }
    }
  }

  Future<void> _copyChat() async {
    final epoch = _historyEpoch;
    final transcript = _history
        .map((turn) => '${turn['role']}: ${turn['content']}')
        .join('\n\n');
    if (!mounted || epoch != _historyEpoch) return;
    await Clipboard.setData(ClipboardData(text: transcript));
    if (!mounted || epoch != _historyEpoch) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copy('Conversation copied.', 'Conversación copiada.')),
      ),
    );
  }

  Future<void> _reloadChat() async {
    final epoch = _historyEpoch;
    final confirmed = await _confirm(
      title: copy('Reload saved chat?', '¿Recargar Chat guardado?'),
      content: Text(
        copy(
          'This replaces the messages shown here with saved history. Copy any unsaved answer first. It will not send an AI request.',
          'Esto reemplaza los mensajes visibles por el historial guardado. Copia primero las respuestas sin guardar. No se enviará ninguna solicitud de IA.',
        ),
      ),
      action: copy('Reload saved chat', 'Recargar Chat guardado'),
    );
    if (confirmed && mounted && epoch == _historyEpoch) await _loadChat();
  }

  Widget _chatHistoryControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Text(
        copy(
          'Saved on this device for this account. Up to 6 recent messages go with your next AI request.',
          'Guardado en este dispositivo para esta cuenta. Tu próxima solicitud de IA incluye hasta 6 mensajes recientes.',
        ),
      ),
      Text(
        // Only a choice the person made is called saved; the default is
        // named as the default; before the chat loads, nothing is claimed.
        !_historyReady
            ? copy(
                'Planning sources: shown once the saved chat loads.',
                'Fuentes de planificación: se muestran cuando se cargue la conversación guardada.',
              )
            : !_sourcesChosen && _sources.isNotEmpty
            ? copy(
                'Planning sources: My plan (${_sources.map(_sourceLabel).join(', ')}), the default.',
                'Fuentes de planificación: Mi plan (${_sources.map(_sourceLabel).join(', ')}), la opción predeterminada.',
              )
            : copy(
                _sources.isEmpty
                    ? 'Saved planning sources: off.'
                    : 'Saved planning sources: ${_sources.map(_sourceLabel).join(', ')}.',
                _sources.isEmpty
                    ? 'Fuentes de planificación: desactivadas.'
                    : 'Fuentes de planificación: ${_sources.map(_sourceLabel).join(', ')}.',
              ),
      ),
      if (_historyLoading)
        Text(copy('Loading saved chat…', 'Cargando conversación guardada…')),
      if (!_historyLoading && !_historyReady) ...[
        Text(
          copy(
            'Saved chat could not be loaded. Retry or explicitly clear it before continuing.',
            'No se pudo cargar la conversación. Reintenta o bórrala explícitamente antes de continuar.',
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _loadChat,
          child: Text(copy('Retry loading chat', 'Reintentar cargar Chat')),
        ),
      ],
      if (_historySaveFailed) ...[
        Text(
          copy(
            'The latest local change could not be saved. Any answer shown is still available here; retrying saves only and does not request AI again.',
            'No se pudo guardar el último cambio local. Las respuestas visibles siguen aquí; reintentar solo guarda y no vuelve a solicitar IA.',
          ),
        ),
        if (_historyReady)
          TextButton(
            onPressed: _busy || _historyLoading ? null : _persistChat,
            child: Text(copy('Retry saving chat', 'Reintentar guardar Chat')),
          ),
      ],
      if (_historyConflict) ...[
        Text(
          copy(
            'Saved chat changed in another view. Messages here remain available to copy. Reload saved chat or explicitly clear the conversation before continuing; an older view cannot overwrite cleared history.',
            'Chat guardado cambió en otra vista. Puedes copiar los mensajes de aquí. Recarga Chat guardado o borra explícitamente la conversación para continuar; una vista anterior no puede sobrescribir un historial borrado.',
          ),
        ),
        TextButton(
          onPressed: _busy || _historyLoading ? null : _reloadChat,
          child: Text(copy('Reload saved chat', 'Recargar Chat guardado')),
        ),
      ],
      if (_historyClearFailed)
        Text(
          copy(
            'The conversation could not be cleared. Saved history may remain. Try Clear conversation again.',
            'No se pudo borrar la conversación. Es posible que el historial siga guardado. Vuelve a intentar Borrar conversación.',
          ),
        ),
      ExpansionTile(
        key: const Key('conversation-history-privacy'),
        title: Text(
          copy('Chat history & privacy', 'Historial de Chat y privacidad'),
        ),
        subtitle: Text(
          copy(
            'Up to 40 messages · copy or clear',
            'Hasta 40 mensajes · copiar o borrar',
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        children: [
          Text(
            copy(
              'Chat keeps up to 40 recent messages on this device for this account; long messages may be shortened. Each AI reply is kept with how many items of each kind of information it used, what it cost and the credits left after it. It is excluded from planning backups and cloud sync. Signing out keeps this account’s saved history on the device; signing back into the same account restores access. Use Clear conversation or clear this account’s local data to delete it. The last 6 messages are included with your next AI request, even when saved planning sources are off. Copy conversation puts the visible text on your clipboard; you choose where to paste it.',
              'Chat conserva hasta 40 mensajes recientes en este dispositivo para esta cuenta; los mensajes largos pueden acortarse. Cada respuesta de IA se guarda con cuántos elementos de cada tipo de información usó, lo que costó y los créditos que quedaron. No se incluyen en las copias de planificación ni se sincronizan con la nube. Al cerrar sesión, el historial guardado de esta cuenta permanece en el dispositivo; puedes volver a verlo al iniciar sesión en la misma cuenta. Usa Borrar conversación o limpia los datos locales de esta cuenta para eliminarlo. Los últimos 6 mensajes se incluyen en tu próxima solicitud de IA, incluso con las fuentes de planificación desactivadas. Copiar conversación pone el texto visible en el portapapeles; tú eliges dónde pegarlo.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            key: const Key('conversation-pending-privacy'),
            copy(
              'While a question you paid for is being answered, it is also kept on this device so the reply can be collected if you leave. It is deleted when the reply is shown. If the reply cannot be collected, it is deleted about 5 minutes after you confirm the price, or when the answer ends if it is still being answered then. If the app is in the background or closed at that time, it is deleted the next time the app runs with this account. A reply that arrived but was not yet shown keeps it until it is shown; if the app closes first, it stays on the device until this account is next opened, and is deleted then.',
              'Mientras se responde una pregunta que pagaste, también se guarda en este dispositivo para poder recibir la respuesta si sales. Se borra cuando se muestra la respuesta. Si la respuesta no se puede recuperar, se borra unos 5 minutos después de confirmar el precio o, si aún se está respondiendo, cuando termine. Si en ese momento la app está en segundo plano o cerrada, se borra la próxima vez que la app se use con esta cuenta. Una respuesta que llegó pero aún no se mostró la conserva hasta que se muestra; si la app se cierra antes, permanece en el dispositivo hasta la próxima vez que se abra esta cuenta y se borra entonces.',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const Key('conversation-copy-history'),
                onPressed: _busy || _historyLoading || _history.isEmpty
                    ? null
                    : _copyChat,
                child: Text(copy('Copy conversation', 'Copiar conversación')),
              ),
              TextButton(
                key: const Key('conversation-clear-history'),
                onPressed: _busy || _historyLoading ? null : _clearChat,
                child: Text(copy('Clear conversation', 'Borrar conversación')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
