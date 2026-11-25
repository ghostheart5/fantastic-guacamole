part of 'smart_planner_screen.dart';

/// Choose a step offers the free on-device planner and AI chat, with one
/// two-way switch. The AI screen stays alive behind the free planner once it
/// was opened, so its conversation, its draft and a running request are not
/// lost by switching, and an account change resets the choice (see
/// assistantChatModeProvider).
extension _PlannerChatMode on _SmartPlannerScreenState {
  bool get _aiChatAvailable => ref.watch(
    assistantConversationSurfaceAvailableProvider(ConversationSurface.planner),
  );

  void _chooseMode({required bool onDevice}) {
    if (!onDevice) _useLocalTools = false;
    ref
        .read(assistantChatModeProvider.notifier)
        .choose(ConversationSurface.planner, onDevice: onDevice);
  }

  /// The switch shown at the top of the free planner (null when AI chat is
  /// not available in this build, so there is nothing to switch to).
  Widget _modeSwitch() {
    if (!_aiChatAvailable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AssistantModeSwitch(
        aiSelected: false,
        enabled: true,
        onChooseOnDevice: () {},
        onChooseAi: () {
          _rebuild(() {
            _aiDraft = _notesController.text.trim();
            if (_aiDraft.isNotEmpty) _aiDraftRevision++;
          });
          _chooseMode(onDevice: false);
        },
      ),
    );
  }

  Widget _buildChat(BuildContext context) {
    final bool onDevice =
        _useLocalTools ||
        ref.watch(assistantOnDeviceModeProvider(ConversationSurface.planner));
    final bool aiAvailable = _aiChatAvailable;
    if (aiAvailable && !onDevice) _aiChatOpened = true;
    if (!aiAvailable || !_aiChatOpened) return _buildOnDevice(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: const ValueKey<String>('planner-ai-chat'),
          child: Offstage(
            offstage: onDevice,
            child: TickerMode(
              enabled: !onDevice,
              child: AssistantConversationScreen(
                isActive: !onDevice,
                surface: ConversationSurface.planner,
                incomingDraft: _aiDraft,
                incomingDraftRevision: _aiDraftRevision,
                onLocalTools: () => _chooseMode(onDevice: true),
                onLocalToolsWithDraft: (String draft) {
                  if (draft.isNotEmpty) {
                    // Controller assignments do not call the field's onChanged
                    // handler. An old plan must not remain actionable for this
                    // new request.
                    _clearChangedCheckIn();
                    _notesController.text = draft;
                  }
                  _chooseMode(onDevice: true);
                },
              ),
            ),
          ),
        ),
        if (onDevice)
          KeyedSubtree(
            key: const ValueKey<String>('planner-on-device'),
            child: _buildOnDevice(context),
          ),
      ],
    );
  }
}
