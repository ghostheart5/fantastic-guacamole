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
      _filter.clear();
      _scenario.clear();
      _intent = SIV2Intent.answer;
      _range = SIV2TimeRange.all;
      _sources = <SIV2Source>{};
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
    try {
      if (repository == null) throw StateError('chat_account_unavailable');
      final saved = await repository.load();
      if (!mounted || epoch != _historyEpoch) return;
      _updateHistory(() {
        _history
          ..clear()
          ..addAll(saved.messages);
        _sources = saved.sources.toSet();
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
      });
    } finally {
      if (mounted && epoch == _historyEpoch) {
        _updateHistory(() => _historyLoading = false);
      }
    }
  }

  // Snapshot only published pairs and source consent. Never persist a request,
  // quote, input draft, task attachment, or response that safety withheld.
  void _persistChat() {
    if (widget.surface != ConversationSurface.si ||
        !_historyReady ||
        _historyConflict) {
      return;
    }
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    final epoch = _historyEpoch;
    final messages = _history
        .map((turn) => Map<String, String>.of(turn))
        .toList();
    final sources = _sources.toSet();
    _historyWriteTail = _historyWriteTail.then((_) async {
      if (epoch != _historyEpoch || _historyConflict) return;
      try {
        final revision = await repository.save(
          expectedRevision: _storedHistoryRevision,
          messages: messages,
          sources: sources,
        );
        if (epoch != _historyEpoch) return;
        _storedHistoryRevision = revision;
        if (mounted) _updateHistory(() => _historySaveFailed = false);
      } on AssistantConversationRevisionConflict {
        if (!mounted || epoch != _historyEpoch) return;
        _updateHistory(() {
          _historyConflict = true;
          _historySaveFailed = false;
        });
      } on Object {
        if (!mounted || epoch != _historyEpoch) return;
        // A local write failure must never retry an already paid AI request.
        _updateHistory(() => _historySaveFailed = true);
      }
    });
  }

  Future<void> _clearChat() async {
    final epoch = _historyEpoch;
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy('Clear conversation?', '¿Borrar la conversación?')),
        content: Text(
          copy(
            'Delete this Chat history from this account on this device and turn saved planning sources off? This cannot be undone. Tasks, goals, and habits stay saved.',
            '¿Borrar el historial de Chat de esta cuenta en este dispositivo y desactivar las fuentes de planificación? No se puede deshacer. Se conservan las tareas, metas y hábitos.',
          ),
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
        _sources = <SIV2Source>{};
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
          'Chat keeps up to 40 recent messages on this device for this account; long messages may be shortened. It is excluded from planning backups and cloud sync. Signing out keeps this account’s saved history on the device; signing back into the same account restores access. Use Clear conversation or clear this account’s local data to delete it. The last 6 messages are included with your next AI request, even when saved planning sources are off.',
          'Chat conserva hasta 40 mensajes recientes en este dispositivo para esta cuenta; los mensajes largos pueden acortarse. No se incluyen en las copias de planificación ni se sincronizan con la nube. Al cerrar sesión, el historial guardado de esta cuenta permanece en el dispositivo; puedes volver a verlo al iniciar sesión en la misma cuenta. Usa Borrar conversación o limpia los datos locales de esta cuenta para eliminarlo. Los últimos 6 mensajes se incluyen en tu próxima solicitud de IA, incluso con las fuentes de planificación desactivadas.',
        ),
      ),
      Text(
        copy(
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
  );
}
