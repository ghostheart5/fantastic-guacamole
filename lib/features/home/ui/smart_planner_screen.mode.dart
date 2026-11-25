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

  /// The switch shown at the top of the free planner. Only a build without AI
  /// chat has nothing to show.
  Widget _modeSwitch() {
    if (!ref.watch(assistantChatInBuildProvider)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AssistantModeSwitch(
        surface: ConversationSurface.planner,
        aiSelected: false,
        enabled: true,
        replyReady: _aiUpdate,
        onChooseOnDevice: () {},
        onChooseAi: () {
          _rebuild(() {
            _aiDraft = _notesController.text.trim();
            _aiDraftRevision++;
            _aiUpdate = false;
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
    ref.listen(accountStorageScopeProvider, (previous, next) {
      if (previous?.v2Namespace == next.v2Namespace) return;
      // Nothing typed or arrived for one account goes to the next.
      _rebuild(() {
        _aiDraft = '';
        _aiUpdate = false;
      });
    });
    if (!aiAvailable && !ref.watch(assistantChatInBuildProvider)) {
      return _buildOnDevice(context);
    }
    final bool mountAi = aiAvailable && (_firstValueDone || !_useLocalTools);
    final bool showOnDevice = onDevice || !mountAi;
    // The AI screen is kept (hidden) so a stored or running paid request is
    // collected while the free planner is shown.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (mountAi)
          KeyedSubtree(
            key: const ValueKey<String>('planner-ai-chat'),
            child: Offstage(
              offstage: showOnDevice,
              child: TickerMode(
                enabled: !showOnDevice,
                child: ExcludeFocus(
                  excluding: showOnDevice,
                  child: AssistantConversationScreen(
                    isActive: !showOnDevice,
                    hidden: showOnDevice,
                    onUpdateWhileHidden: () {
                      if (mounted) _rebuild(() => _aiUpdate = true);
                    },
                    surface: ConversationSurface.planner,
                    incomingDraft: _aiDraft,
                    incomingDraftRevision: _aiDraftRevision,
                    onLocalTools: () => _chooseMode(onDevice: true),
                    onLocalToolsWithDraft: (String draft) {
                      // An empty AI box keeps the free planner's notes and plan.
                      if (draft.isNotEmpty && draft != _notesController.text) {
                        // Controller assignments do not call the field's
                        // onChanged handler. An old plan must not remain
                        // actionable for this new request.
                        _clearChangedCheckIn();
                        _notesController.text = draft;
                      }
                      _chooseMode(onDevice: true);
                    },
                  ),
                ),
              ),
            ),
          ),
        if (showOnDevice)
          KeyedSubtree(
            key: const ValueKey<String>('planner-on-device'),
            child: _buildOnDevice(context),
          ),
      ],
    );
  }
}
