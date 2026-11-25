part of 'assistant_conversation_screen.dart';

/// Sending a paid message in one step. The send button states the price
/// ([conversationMessageCredits]) and tapping it confirms that price. The
/// full preview of what is sent opens by itself before the first message
/// after the app opens and whenever the selected information changes, and
/// See what is sent opens it at any time. A signed price different from the
/// one on the button is asked about before anything is charged. A question
/// the on-device tools can answer gets a suggestion that never blocks send.
extension _OneStepSend on _AssistantConversationScreenState {
  String get _sendLabel => copy(
    'Send · $conversationMessageCredits credits',
    'Enviar · $conversationMessageCredits créditos',
  );

  /// What a request carries besides the messages, as selected: a change to
  /// any of it shows the full preview again. Free text is compared in memory
  /// only and never stored.
  String _selectionKey(ConversationPacket packet) {
    final context = packet.toJson()['context'] as Map;
    return jsonEncode([
      (_sources.map((source) => source.name).toList()..sort()),
      _range.name,
      _intent.name,
      _filter.text.trim(),
      _scenario.text.trim(),
      _attachedTaskId,
      _attachedTaskOnly,
      _energy != null,
      context['contextScope'],
      context['selectedNoteId'],
      context['reportedEmotion'] != null,
    ]);
  }

  /// The full preview: the question, the recent messages and every record
  /// the request carries, all visible without another tap.
  Future<bool> _reviewWhatIsSent(String prompt, ConversationPacket packet) {
    final recent = (packet.toJson()['history'] as List)
        .whereType<Map<Object?, Object?>>()
        .map(
          (turn) =>
              '${turn['role'] == 'user' ? copy('You', 'Tú') : copy('AI chat', 'Chat con IA')}: ${turn['content']}',
        )
        .join('\n\n');
    const heading = TextStyle(fontWeight: FontWeight.bold);
    return _confirm(
      title: copy(
        'Review what AI will receive',
        'Revisa lo que recibirá la IA',
      ),
      content: Column(
        key: const Key('conversation-preview-content'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            copy(
              'Your question, the recent messages and the information below go to Axiomara to check the price, then to Anthropic for a reply. Sending costs $conversationMessageCredits credits; nothing is sent or charged if you cancel. Anthropic normally keeps API content for up to 30 days. This does not save or change your tasks.',
              'Tu pregunta, los mensajes recientes y la información de abajo se envían a Axiomara para comprobar el precio y luego a Anthropic para responder. Enviar cuesta $conversationMessageCredits créditos; si cancelas, no se envía ni se cobra nada. Anthropic normalmente conserva el contenido de la API hasta 30 días. Esto no guarda ni modifica tus tareas.',
            ),
          ),
          const SizedBox(height: 12),
          Text(copy('Your question', 'Tu pregunta'), style: heading),
          SelectableText(prompt),
          const SizedBox(height: 12),
          Text(copy('Recent messages', 'Mensajes recientes'), style: heading),
          SelectableText(
            recent.isEmpty ? copy('None yet', 'Ninguno todavía') : recent,
          ),
          const SizedBox(height: 12),
          Text(
            copy('Included app context', 'Contexto incluido'),
            style: heading,
          ),
          SelectableText(_contextPreview(packet)),
          const SizedBox(height: 12),
          Text(
            copy(
              'This review opens by itself before your first message and whenever the information used changes. See what is sent shows it at any time.',
              'Esta revisión se abre sola antes de tu primer mensaje y cada vez que cambia la información que se usa. Ver qué se envía la muestra en cualquier momento.',
            ),
          ),
        ],
      ),
      action: copy('Send', 'Enviar'),
    );
  }

  /// Asked only when the signed price is not the one the button showed.
  Future<bool> _confirmChangedPrice(int credits) => _confirm(
    title: copy('The price is different', 'El precio es distinto'),
    content: Text(
      copy(
        'This reply costs $credits credits, not the $conversationMessageCredits shown on the send button. Nothing has been charged. Send it for $credits credits?',
        'Esta respuesta cuesta $credits créditos, no los $conversationMessageCredits que mostraba el botón de enviar. No se ha cobrado nada. ¿Enviarla por $credits créditos?',
      ),
    ),
    action: copy('Use $credits credits', 'Usar $credits créditos'),
  );

  void _onDraftChanged() => unawaited(_refreshFreeSuggestion());

  /// On-device classification of the draft only; nothing is sent.
  Future<void> _refreshFreeSuggestion() async {
    final check = ++_suggestionCheck;
    final text = _input.text.trim();
    final scope = ref.read(accountStorageScopeProvider).v2Namespace;
    var suggest = false;
    if (text.isNotEmpty && scope != null) {
      try {
        final decision = await ref
            .read(axiomaraRouterProvider)
            .route(
              accountScopeId: scope,
              input: text,
              externalAiAllowed: ref
                  .read(personalizationProfileProvider)
                  .externalAiAllowed,
            );
        suggest =
            decision.route == AxiomaraRoute.local ||
            decision.route == AxiomaraRoute.si;
      } on Object {
        suggest = false;
      }
    } else {
      // Never rebuild inside the caller's own rebuild.
      await Future<void>.value();
    }
    if (!mounted || check != _suggestionCheck || suggest == _freeSuggested) {
      return;
    }
    _rebuild(() => _freeSuggested = suggest);
  }

  void _openFreeTools(String draft) {
    final handoff = widget.onLocalToolsWithDraft;
    if (handoff == null) {
      widget.onLocalTools();
    } else {
      handoff(draft);
    }
  }

  Widget _freeSuggestion() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const Key('conversation-free-suggestion'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.cyanAccent,
          minimumSize: const Size(48, 48),
        ),
        onPressed: _busy ? null : () => _openFreeTools(_input.text.trim()),
        icon: const Icon(Icons.offline_bolt_outlined),
        label: Text(
          copy(
            'Answer free on this device',
            'Responder gratis en este dispositivo',
          ),
        ),
      ),
    ),
  );

  /// With AI chat on: the paid send, labelled with its price, and the
  /// preview. At large text the preview is an icon with the same name and
  /// the send icon is left out, so both stay on one row.
  Widget _sendControls({required bool enabled, required bool listening}) {
    final onSend = enabled && !listening ? () => _send() : null;
    final onPreview = enabled && !listening
        ? () => _send(showPreview: true)
        : null;
    final previewLabel = copy('See what is sent', 'Ver qué se envía');
    const sendStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, 48)),
    );
    if (MediaQuery.textScalerOf(context).scale(14) > 21) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            key: const Key('conversation-preview'),
            color: Colors.cyanAccent,
            tooltip: previewLabel,
            onPressed: onPreview,
            icon: const Icon(Icons.visibility_outlined),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FilledButton(
              key: const Key('conversation-send'),
              style: sendStyle,
              onPressed: onSend,
              child: Text(_sendLabel, textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          key: const Key('conversation-preview'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.cyanAccent,
            minimumSize: const Size(48, 48),
          ),
          onPressed: onPreview,
          child: Text(previewLabel),
        ),
        FilledButton.icon(
          key: const Key('conversation-send'),
          style: sendStyle,
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
          label: Text(_sendLabel),
        ),
      ],
    );
  }

  /// With AI chat off nothing can be sent, so no price is shown: the button
  /// offers the consent sheet rather than silently doing nothing.
  Widget _offSendButton({required bool listening}) => IconButton(
    key: const Key('conversation-send'),
    color: Colors.white38,
    disabledColor: Colors.white38,
    tooltip: copy('Send to AI', 'Enviar a IA'),
    onPressed: !listening && widget.isActive && !_busy ? _turnOnAiChat : null,
    icon: const Icon(Icons.send_rounded),
  );
}
