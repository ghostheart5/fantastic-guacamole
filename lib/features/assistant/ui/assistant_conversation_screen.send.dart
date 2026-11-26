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
      (_extras.map((source) => source.name).toList()..sort()),
      // Each time the extras go from none to some counts as a new selection,
      // even if the same ones were accepted earlier in this app run (after
      // Clear, Just this chat, reopening or an account change).
      _extras.isEmpty ? null : _extrasEpoch,
      _range.name,
      _intent.name,
      _filter.text.trim(),
      _scenario.text.trim(),
      _attachedTaskId,
      _attachedTaskOnly,
      context['contextScope'],
      // Values, not just presence: a different note, energy or emotional
      // state is different information.
      context['reportedEnergy'],
      context['reportedEmotion'],
      context['selectedNoteId'],
      context['explicitlyAttachedNote'],
    ]);
  }

  /// The app's own bilingual name for an emotional state.
  String _emotionName(String name) =>
      ChronoSparkLocalizations.of(context).plannerRoutine.emotionName(name);

  /// Choose a step has no choice row: this read-only line names what its
  /// requests carry, matching ConversationPacketFactory.build.
  Widget _plannerScopeLine() {
    final taskOnly = _attachedTaskId != null && _attachedTaskOnly;
    final note = taskOnly
        ? null
        : ref.watch(selectedPlanningNoteProvider).asData?.value;
    final human = ref.watch(consentedHumanContextProvider);
    final emotion = !taskOnly && human.emotionAllowed ? human.emotion : null;
    final energy = human.authorizeReportedEnergy(_energy);
    final parts = <String>[
      taskOnly
          ? copy('only the task you attached', 'solo la tarea que adjuntaste')
          : copy(
              'tasks, goals, milestones and schedule picked for your question',
              'tareas, metas, hitos y agenda elegidos para tu pregunta',
            ),
      if (!taskOnly && _attachedTaskId != null)
        copy('the task you attached', 'la tarea que adjuntaste'),
      if (note != null)
        copy('your note “${note.title}”', 'tu nota «${note.title}»'),
      if (energy != null)
        copy(
          'your energy (${(energy * 100).round()}%)',
          'tu energía (${(energy * 100).round()}%)',
        ),
      if (emotion != null)
        copy(
          'your emotional state (${_emotionName(emotion.name)})',
          'tu estado emocional (${_emotionName(emotion.name)})',
        ),
    ];
    return Text(
      key: const Key('conversation-planner-scope'),
      copy(
        'AI chat uses: ${parts.join('; ')}.',
        'El chat con IA usa: ${parts.join('; ')}.',
      ),
      style: const TextStyle(color: Colors.white70),
    );
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
          Text(copy('Also sent', 'También se envía'), style: heading),
          SelectableText(
            copy(
              'With these: identifiers for the records and the links between them (such as a task’s goal), completion flags and record types, which records matter most for your question, which sources could not be read, a version marker for your plan data, your local date and time, time zone and language.',
              'Junto con esto: identificadores de los registros y los vínculos entre ellos (como la meta de una tarea), marcas de completado y tipos de registro, qué registros importan más para tu pregunta, qué fuentes no se pudieron leer, un marcador de versión de tus datos de plan, tu fecha y hora local, zona horaria e idioma.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            copy(
              'This review opens by itself before your first message after the app opens and whenever you change the information selected, including the note, energy or emotional state. Once you have typed a question, See what is sent by the message box shows it whenever sending is available.',
              'Esta revisión se abre sola antes de tu primer mensaje después de abrir la app y cada vez que cambias la información elegida, incluida la nota, la energía o el estado emocional. Cuando hayas escrito una pregunta, Ver qué se envía, junto al cuadro de mensaje, la muestra siempre que se pueda enviar.',
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

  /// Large text, or somewhat enlarged text while the extra choices are shown:
  /// their row makes the controls taller, so from 1.2 times text the layout is
  /// the large-text one (the controls scroll within half the screen).
  bool get _largeText {
    final scaled = MediaQuery.textScalerOf(context).scale(14);
    return scaled > 21 ||
        (scaled > 16.8 &&
            widget.surface == ConversationSurface.si &&
            ref.read(aiChatExtraSourcesAvailableProvider));
  }

  String get _previewLabel => copy('See what is sent', 'Ver qué se envía');

  VoidCallback? _onPreview({required bool enabled, required bool listening}) =>
      enabled && !listening ? () => _send(showPreview: true) : null;

  /// At large text the preview is an icon with the same name, placed next to
  /// the input so the send button gets the full width.
  Widget _previewIconButton({required bool enabled, required bool listening}) =>
      IconButton(
        key: const Key('conversation-preview'),
        color: Colors.cyanAccent,
        disabledColor: Colors.white38,
        tooltip: _previewLabel,
        onPressed: _onPreview(enabled: enabled, listening: listening),
        icon: const Icon(Icons.visibility_outlined),
      );

  /// With AI chat on: the paid send, labelled with its price, and (at
  /// regular text size) the preview beside it. At large text the send icon
  /// is left out so the label wraps less.
  Widget _sendControls({required bool enabled, required bool listening}) {
    final onSend = enabled && !listening ? () => _send() : null;
    final onPreview = _onPreview(enabled: enabled, listening: listening);
    final previewLabel = _previewLabel;
    const sendStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, 48)),
    );
    if (_largeText) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: FilledButton(
          key: const Key('conversation-send'),
          style: sendStyle,
          onPressed: onSend,
          child: Text(_sendLabel, textAlign: TextAlign.center),
        ),
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

  /// The controls below the conversation. At large text they take at most
  /// half of the visible height and scroll, anchored at the bottom so
  /// the input and send stay in view, leaving the conversation room.
  Widget _boundedBottom(List<Widget> children) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    if (!_largeText) return column;
    final media = MediaQuery.of(context);
    final visible =
        media.size.height - media.viewInsets.bottom - media.padding.vertical;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: visible * 0.5 < 160 ? 160 : visible * 0.5,
      ),
      child: SingleChildScrollView(reverse: true, child: column),
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
