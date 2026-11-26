part of 'assistant_conversation_screen.dart';

/// What AI chat uses when the person has not chosen: their plan, meaning the
/// planning sources that exist today. Listed by name so a source added later
/// is never sent by default without its own decision.
const _myPlanSources = <SIV2Source>{
  SIV2Source.tasks,
  SIV2Source.goals,
  SIV2Source.milestones,
  SIV2Source.timeline,
};

/// The information Chat uses: a row of choices above the input and a one-time
/// line explaining the default. The full preview of what a request carries
/// opens by itself when this choice changes (see the send part).
extension _ConversationScope on _AssistantConversationScreenState {
  /// The choice saved with the chat, or the plan when the person never chose.
  /// Call inside a rebuild.
  void _applySavedScope(AssistantConversationHistory saved) {
    _sourcesChosen = saved.sourcesChosen;
    _extras = <ConversationExtraSource>{};
    _sources = saved.sourcesChosen
        ? saved.sources.toSet()
        : {..._myPlanSources};
    _scopeExplained = saved.scopeExplained;
    _scopeNoticeVisible = !saved.sourcesChosen && !saved.scopeExplained;
  }

  /// After Clear conversation the default applies again. Call inside a
  /// rebuild.
  void _applyDefaultScope() {
    _sourcesChosen = false;
    _extras = <ConversationExtraSource>{};
    _sources = {..._myPlanSources};
    _scopeNoticeVisible = !_scopeExplained;
  }

  /// The person's own choice, saved with the chat.
  void _chooseSources(Set<SIV2Source> sources) {
    _rebuild(() {
      _sources = sources;
      // Extra information adds to saved information: Just this chat has none.
      if (sources.isEmpty) _extras = <ConversationExtraSource>{};
      _sourcesChosen = true;
      _scopeNoticeVisible = false;
    });
    _persistChat();
  }

  /// Remembers for this account that the explanation was shown, once.
  void _recordScopeExplained() {
    if (_scopeExplained) return;
    final repository = ref.read(assistantConversationHistoryRepositoryProvider);
    if (repository == null) return;
    _scopeExplained = true;
    unawaited(() async {
      try {
        await repository.markScopeExplained();
      } on Object {
        // Not saved: the line is shown again next time, nothing else changes.
      }
    }());
  }

  Widget _scopeNotice() {
    // Counted as seen only when the person can actually see it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive && _scopeNoticeVisible) {
        _recordScopeExplained();
      }
    });
    return Padding(
      key: const Key('conversation-scope-notice'),
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        copy(
          'AI chat now uses your plan (tasks, goals, milestones and schedule) so replies fit your day. See what is sent shows what goes, and it opens by itself before your first message each time the app opens and whenever this choice changes. Choose Just this chat to send none of it.',
          'El chat con IA ahora usa tu plan (tareas, metas, hitos y agenda) para que las respuestas se ajusten a tu día. Ver qué se envía muestra lo que se envía, y se abre solo antes de tu primer mensaje cada vez que abres la app y cada vez que cambia esta elección. Elige Solo esta conversación para no enviar nada de tu plan.',
        ),
        style: const TextStyle(color: Colors.cyanAccent),
      ),
    );
  }

  Widget _scopeChips({required bool enabled}) {
    final myPlan =
        _sources.length == _myPlanSources.length &&
        _sources.containsAll(_myPlanSources);
    final chatOnly = _sources.isEmpty;
    final chosen = SIV2Source.values
        .where(_sources.contains)
        .map(_sourceLabel)
        .join(', ');
    Widget chip({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: enabled ? (_) => onTap() : null,
      ),
    );

    final main = Semantics(
      container: true,
      label: copy(
        'Information AI chat uses',
        'Información que usa el chat con IA',
      ),
      // Wraps rather than scrolls sideways, so every choice stays in view
      // with large text on a narrow screen.
      child: Wrap(
        key: const Key('conversation-scope'),
        children: [
          chip(
            key: const Key('conversation-scope-my-plan'),
            label: copy('My plan', 'Mi plan'),
            selected: myPlan,
            onTap: () => _chooseSources({..._myPlanSources}),
          ),
          chip(
            key: const Key('conversation-scope-chat-only'),
            label: copy('Just this chat', 'Solo esta conversación'),
            selected: chatOnly,
            onTap: () => _chooseSources(<SIV2Source>{}),
          ),
          // A label, not a control: single sources are chosen under
          // Choose information to use.
          if (!myPlan && !chatOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Chip(
                key: const Key('conversation-scope-custom'),
                avatar: const Icon(Icons.check, size: 18),
                label: Text(copy('$chosen only', 'Solo $chosen')),
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
        ],
      ),
    );
    // The extra choices exist only in a build whose switch is on.
    if (!ref.watch(aiChatExtraSourcesAvailableProvider)) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        main,
        _extraSourceChips(enabled: enabled && _sources.isNotEmpty),
      ],
    );
  }

  /// Optional extra information, off until turned on for this chat. Each
  /// choice shows its lines in the review before anything is sent.
  Widget _extraSourceChips({required bool enabled}) {
    Widget chip(ConversationExtraSource source) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        key: Key('conversation-extra-${source.name}'),
        label: Text(_extraLabel(source)),
        tooltip: _extraDetail(source),
        selected: _extras.contains(source),
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: enabled
            ? (on) {
                _rebuild(() {
                  _extras = on
                      ? {..._extras, source}
                      : ({..._extras}..remove(source));
                });
              }
            : null,
      ),
    );

    return Semantics(
      container: true,
      label: copy(
        'More information AI chat can use, off unless you turn it on',
        'Más información que puede usar el chat con IA, desactivada salvo que la actives',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // While any is on, this line replaces the heading and names what is
          // on with the dates each covers: the full preview opens again only
          // when the selection changes, so what rides along with every later
          // message is always in view next to the input.
          Padding(
            key: _extras.isEmpty
                ? null
                : const Key('conversation-extra-status'),
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _extras.isEmpty
                  ? copy(
                      'Add more, listed in See what is sent (off unless you turn it on)',
                      'Añadir más, se muestra en Ver qué se envía (desactivado salvo que lo actives)',
                    )
                  : copy(
                      'On for every message in this chat until you turn it off: ${_extraSummary()}',
                      'Activado en cada mensaje de este chat hasta que lo desactives: ${_extraSummary()}',
                    ),
            ),
          ),
          Wrap(
            key: const Key('conversation-extra-sources'),
            children: [
              for (final source in ConversationExtraSource.values) chip(source),
            ],
          ),
        ],
      ),
    );
  }

  /// The chosen extras with the dates each one really covers.
  String _extraSummary() {
    final window = ConversationRecentWindow.forRange(_range);
    return ConversationExtraSource.values
        .where(_extras.contains)
        .map(
          (source) => switch (source) {
            ConversationExtraSource.habits => copy(
              'Habits (check-ins: last 14 days)',
              'Hábitos (registros: últimos 14 días)',
            ),
            ConversationExtraSource.recentTasks => copy(
              'Recent results (${_recentWindowWords(window)})',
              'Resultados recientes (${_recentWindowWords(window)})',
            ),
            ConversationExtraSource.goalProgress => copy(
              'Goal progress (all time)',
              'Progreso de metas (todo el tiempo)',
            ),
          },
        )
        .join('; ');
  }

  /// What a choice adds, read out and shown as its tooltip.
  String _extraDetail(ConversationExtraSource source) => switch (source) {
    ConversationExtraSource.habits => copy(
      'Habit names, check-ins in the last 14 days and streak',
      'Nombres de hábitos, registros de los últimos 14 días y racha',
    ),
    ConversationExtraSource.recentTasks => copy(
      'Titles of tasks you finished or skipped, with the date and time, within your selected dates (at most 14 days)',
      'Títulos de las tareas que terminaste u omitiste, con fecha y hora, dentro de las fechas elegidas (como máximo 14 días)',
    ),
    ConversationExtraSource.goalProgress => copy(
      'Each goal title with how many linked tasks and milestones are done or open, all time',
      'Cada título de meta con cuántas tareas e hitos vinculados están hechos o abiertos, en total',
    ),
  };

  String _extraLabel(ConversationExtraSource source) => switch (source) {
    ConversationExtraSource.habits => copy('Habits', 'Hábitos'),
    ConversationExtraSource.recentTasks => copy(
      'Recent results',
      'Resultados recientes',
    ),
    ConversationExtraSource.goalProgress => copy(
      'Goal progress',
      'Progreso de metas',
    ),
  };
}
