part of 'assistant_conversation_screen.dart';

/// The optional controls above the conversation: a saved task and energy for
/// Choose a step, and the information to use for Chat.
extension _ConversationOptions on _AssistantConversationScreenState {
  List<Widget> _conversationOptions({
    required bool planner,
    required bool enabled,
    required List<SIV2TaskEvidence>? tasks,
  }) => [
    if (planner && tasks != null)
      DropdownButtonFormField<String>(
        key: ValueKey('conversation-task-${_attachedTaskId ?? 'none'}'),
        initialValue: tasks.any((t) => t.id == _attachedTaskId)
            ? _attachedTaskId
            : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: copy(
            'Use a saved task (optional)',
            'Usar una tarea guardada (opcional)',
          ),
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(copy('No specific task', 'Sin tarea específica')),
          ),
          ...tasks.map(
            (t) => DropdownMenuItem(
              value: t.id,
              child: Text(
                t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: enabled
            ? (value) => _rebuild(() {
                _attachedTaskId = value == '' ? null : value;
                _attachedTaskOnly = true;
                _history.clear();
                _pending = null;
              })
            : null,
      ),
    if (planner && _attachedTaskId != null)
      SwitchListTile(
        key: const Key('conversation-task-only'),
        contentPadding: EdgeInsets.zero,
        title: Text(copy('Use only this task', 'Usar solo esta tarea')),
        subtitle: Text(
          copy(
            'Turn off to review broader app context. Changing this starts a new conversation.',
            'Desactiva para revisar más contexto de la app. Cambiar esto inicia una conversación nueva.',
          ),
        ),
        value: _attachedTaskOnly,
        onChanged: enabled
            ? (value) => _rebuild(() {
                _attachedTaskOnly = value;
                _history.clear();
                _pending = null;
              })
            : null,
      ),
    if (planner)
      ExpansionTile(
        childrenPadding: const EdgeInsets.only(top: 16, bottom: 8),
        title: Text(
          copy(
            'How much energy do you have? (optional)',
            '¿Cuánta energía tienes? (opcional)',
          ),
        ),
        children: [
          DropdownButtonFormField<double>(
            isExpanded: true,
            key: ValueKey('conversation-energy-$_generation'),
            initialValue: _energy,
            decoration: InputDecoration(
              labelText: copy('Energy (optional)', 'Energía (opcional)'),
            ),
            hint: Text(copy('Not set', 'Sin indicar')),
            items: [
              DropdownMenuItem(
                value: -1,
                child: Text(copy('Not set', 'Sin indicar')),
              ),
              for (var percent = 0; percent <= 100; percent += 10)
                DropdownMenuItem(
                  value: percent / 100,
                  child: Text('$percent%'),
                ),
              if (_energy != null &&
                  ![for (var i = 0; i <= 10; i++) i / 10].contains(_energy))
                DropdownMenuItem(
                  value: _energy,
                  child: Text('${(_energy! * 100).round()}%'),
                ),
            ],
            onChanged: enabled
                ? (v) => _rebuild(() => _energy = v == -1 ? null : v)
                : null,
          ),
        ],
      ),
    if (!planner)
      ExpansionTile(
        key: const Key('conversation-advanced'),
        childrenPadding: const EdgeInsets.only(top: 16, bottom: 8),
        title: Text(
          copy(
            'Choose information to use (optional)',
            'Elegir información que usar (opcional)',
          ),
        ),
        children: [
          DropdownButtonFormField<SIV2Intent>(
            isExpanded: true,
            key: ValueKey('conversation-mode-$_generation'),
            initialValue: _intent,
            decoration: InputDecoration(
              labelText: copy('What kind of help?', '¿Qué tipo de ayuda?'),
            ),
            items: SIV2Intent.values
                .map(
                  (v) =>
                      DropdownMenuItem(value: v, child: Text(_intentLabel(v))),
                )
                .toList(),
            onChanged: enabled ? (v) => _rebuild(() => _intent = v!) : null,
          ),
          DropdownButtonFormField<SIV2TimeRange>(
            isExpanded: true,
            key: ValueKey('conversation-range-$_generation'),
            initialValue: _range,
            decoration: InputDecoration(
              labelText: copy('Date range', 'Fechas'),
            ),
            items: SIV2TimeRange.values
                .map(
                  (v) =>
                      DropdownMenuItem(value: v, child: Text(_rangeLabel(v))),
                )
                .toList(),
            onChanged: enabled ? (v) => _rebuild(() => _range = v!) : null,
          ),
          Wrap(
            spacing: 8,
            children: SIV2Source.values
                .map(
                  (s) => FilterChip(
                    label: Text(_sourceLabel(s)),
                    selected: _sources.contains(s),
                    onSelected: !enabled
                        ? null
                        : (selected) {
                            _rebuild(() {
                              if (selected) {
                                _sources = {..._sources, s};
                              } else {
                                _sources = {..._sources}..remove(s);
                              }
                            });
                            _persistChat();
                          },
                  ),
                )
                .toList(),
          ),
          TextButton(
            onPressed: !enabled
                ? null
                : () {
                    _rebuild(() {
                      _sources = <SIV2Source>{};
                      _attachedTaskId = null;
                      _energy = null;
                      _pending = null;
                    });
                    _persistChat();
                  },
            child: Text(
              copy('Use just this chat', 'Usar solo esta conversación'),
            ),
          ),
          if (_sources.isEmpty && _attachedTaskId == null)
            Text(
              copy(
                'Saved planning records are off. Earlier messages in this chat still apply.',
                'No se incluyen registros de planificación. Los mensajes anteriores de esta conversación aún se usan.',
              ),
            ),
          TextField(
            key: const Key('conversation-entity-filter'),
            controller: _filter,
            enabled: enabled,
            maxLength: 120,
            decoration: InputDecoration(
              counterStyle: const TextStyle(color: Colors.white70),
              labelText: copy(
                'Filter saved titles',
                'Filtrar títulos guardados',
              ),
            ),
          ),
          TextField(
            key: const Key('conversation-scenario'),
            controller: _scenario,
            enabled: enabled,
            maxLength: 500,
            decoration: InputDecoration(
              counterStyle: const TextStyle(color: Colors.white70),
              labelText: copy(
                'Scenario to explore',
                'Escenario que quieres explorar',
              ),
            ),
          ),
        ],
      ),
  ];
}
