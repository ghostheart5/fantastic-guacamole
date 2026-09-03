import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';
import 'package:fantastic_guacamole/domain/strategic/si_console_shortcut_registry.dart';
import 'package:fantastic_guacamole/domain/value_objects/ai_content_report_reason.dart';
import 'package:fantastic_guacamole/state/controllers/si_console_query_controller.dart';
import 'package:fantastic_guacamole/state/controllers/app_flow_controller.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/ai_content_report_provider.dart';
import 'package:fantastic_guacamole/state/providers/si_v2_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:fantastic_guacamole/ui/widgets/typing_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

part 'si_console_screen.widgets.dart';

class _Msg {
  const _Msg({
    required this.text,
    required this.isUser,
    this.emotion,
    this.rationale,
    this.processingMode = AIProcessingMode.unknown,
    this.systemPanel = false,
    this.siV2,
  });
  final String text;
  final bool isUser;
  final String? emotion;
  final String? rationale;
  final AIProcessingMode processingMode;
  final bool systemPanel;
  final SIV2Response? siV2;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SIConsoleScreen extends ConsumerStatefulWidget {
  const SIConsoleScreen({super.key});

  @override
  ConsumerState<SIConsoleScreen> createState() => _SIConsoleScreenState();
}

class _SIConsoleScreenState extends ConsumerState<SIConsoleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final List<_Msg> _messages = [];
  final TextEditingController _input = TextEditingController();
  final TextEditingController _entityFilter = TextEditingController();
  final TextEditingController _scenarioAssumption = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _composerKey = GlobalKey();
  final GlobalKey _latestResponseKey = GlobalKey();
  // Starting guess only, replaced by the composer's real measured height
  // right after the first frame — see _measureComposer.
  final ValueNotifier<double> _composerHeight = ValueNotifier<double>(220);
  bool _typing = false;
  SIV2Intent _intent = SIV2Intent.answer;
  Set<SIV2Source> _sources = SIV2Source.values.toSet();
  SIV2TimeRange _timeRange = SIV2TimeRange.thirtyDays;
  int _latestResponseScrollRequest = 0;
  String? _boundPersonContextRevision;
  late final AnimationController _typingAnim;

  static const String _personContextChangedReason =
      'person_context_revision_changed';
  static const String _personContextChangedMessage =
      'Your Person Context changed, so previous SI evidence responses were '
      'cleared. Ask again to use the current evidence.';

  /// Captured in [initState] because `ref` cannot be read from [dispose] —
  /// the element is already deactivated by then and Riverpod throws.
  late final Future<void> Function() _stopVoice;
  late final Future<void> Function({
    required String surface,
    required List<String> controls,
  })
  _speakAccessibilityHint;

  void _runAfterBuild(VoidCallback action) {
    if (!mounted) return;
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      action();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  void _safeSetState(VoidCallback fn) {
    _runAfterBuild(() => setState(fn));
  }

  void _invalidatePersonContextDependentResponses(
    String currentRevision, {
    bool forceNotice = false,
  }) {
    _safeSetState(() {
      if (!forceNotice &&
          (_boundPersonContextRevision == null ||
              _boundPersonContextRevision == currentRevision)) {
        return;
      }
      final bool removedResponse = _messages.any(
        (_Msg message) => message.siV2 != null,
      );
      _messages.removeWhere((_Msg message) => message.siV2 != null);
      _boundPersonContextRevision = currentRevision;
      if ((forceNotice || removedResponse) &&
          !_messages.any(
            (_Msg message) => message.rationale == _personContextChangedReason,
          )) {
        _messages.add(
          const _Msg(
            text: _personContextChangedMessage,
            isUser: false,
            emotion: 'cautious',
            rationale: _personContextChangedReason,
            systemPanel: true,
            processingMode: AIProcessingMode.onDevice,
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final voiceService = ref.read(voiceServiceProvider);
    _stopVoice = voiceService.stop;
    _speakAccessibilityHint = voiceService.speakAccessibilityHint;
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MediaQueryData media = MediaQuery.of(context);
    if (media.disableAnimations || media.accessibleNavigation) {
      _typingAnim
        ..stop()
        ..value = .5;
    } else if (!_typingAnim.isAnimating) {
      unawaited(_typingAnim.repeat());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingAnim.dispose();
    _input.dispose();
    _entityFilter.dispose();
    _scenarioAssumption.dispose();
    _scroll.dispose();
    _composerHeight.dispose();
    unawaited(_stopVoice());
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // The keyboard opening/closing resizes the viewport without the SI
    // Console ever leaving resizeToAvoidBottomInset: false, so nothing else
    // re-anchors the transcript to the latest message when that happens.
    // Re-measure first: the keyboard toggle also flips the composer between
    // its compact/expanded layouts, and scrolling before that resize lands
    // would jump to a since-stale maxScrollExtent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureComposer();
      _scrollToBottom();
    });
  }

  void _measureComposer() {
    final double? height = _composerKey.currentContext?.size?.height;
    if (height != null && height != _composerHeight.value) {
      _composerHeight.value = height;
    }
  }

  Future<void> _showReportDialog(_Msg msg) async {
    AiContentReportReason selected = AiContentReportReason.unsafe;
    final AiContentReportReason?
    reason = await showDialog<AiContentReportReason>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0C1420),
              surfaceTintColor: Colors.transparent,
              title: const Text('Report response'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Only the selected response and your reason are sent for safety review. Your prompt and conversation history are not included.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<AiContentReportReason>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Reason'),
                      items:
                          <AiContentReportReason>[
                                AiContentReportReason.unsafe,
                                AiContentReportReason.inaccurate,
                                AiContentReportReason.privacy,
                                AiContentReportReason.other,
                              ]
                              .map(
                                (AiContentReportReason option) =>
                                    DropdownMenuItem<AiContentReportReason>(
                                      value: option,
                                      child: Text(switch (option) {
                                        AiContentReportReason.unsafe =>
                                          'Unsafe or harmful',
                                        AiContentReportReason.inaccurate =>
                                          'Misleading or inaccurate',
                                        AiContentReportReason.privacy =>
                                          'Privacy concern',
                                        AiContentReportReason.other => 'Other',
                                      }),
                                    ),
                              )
                              .toList(growable: false),
                      onChanged: (AiContentReportReason? value) {
                        if (value != null) setState(() => selected = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selected),
                  child: const Text('Send report'),
                ),
              ],
            );
          },
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(aiContentReportActionsProvider)
          .submit(responseText: msg.text, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thanks. The response was reported for safety review.',
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The response could not be reported. Please try again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAccessibilityGuide() async {
    if (!mounted) {
      return;
    }
    const List<String> controls = <String>[
      'Type a prompt in the input field, then tap send.',
      'Use Summary to hear recent assistant responses.',
      'Use Speak on assistant bubbles to read aloud.',
      'Use Back to return to Nexus.',
    ];
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0C1420),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Accessibility Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Use these controls for readable and spoken guidance.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '1. Type a prompt, then send.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '2. Summary reads recent assistant responses.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '3. Speak reads one response aloud.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '4. Back returns to Nexus.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      },
    );
    unawaited(
      _speakAccessibilityHint(surface: 'SI Console', controls: controls),
    );
  }

  void _addShortcutResponse({
    required String query,
    required String response,
    required SIConsoleShortcutDefinition definition,
    String emotion = 'engaged',
  }) {
    final AIRecommendation typed = ref
        .read(siConsoleQueryControllerProvider)
        .localShortcutResponse(
          query: query,
          response: response,
          shortcut: definition.shortcut,
          emotion: emotion,
        );
    _appendLocalResponse(query: query, typed: typed, fallbackEmotion: emotion);
  }

  void _addShortcutFallback({
    required String query,
    required String response,
    required String reason,
  }) {
    final AIRecommendation typed = ref
        .read(siConsoleQueryControllerProvider)
        .localFallbackResponse(
          query: query,
          response: response,
          reason: reason,
        );
    _appendLocalResponse(
      query: query,
      typed: typed,
      fallbackEmotion: 'balanced',
    );
  }

  void _appendLocalResponse({
    required String query,
    required AIRecommendation typed,
    required String fallbackEmotion,
  }) {
    typed.contract!.validate();
    _safeSetState(() {
      _messages.add(_Msg(text: query, isUser: true));
      _messages.add(
        _Msg(
          text: typed.message,
          isUser: false,
          emotion: typed.emotion ?? fallbackEmotion,
          rationale: typed.reasoning,
          systemPanel: true,
          processingMode: typed.processingMode,
        ),
      );
    });
    _scrollToLatestResponse();
  }

  void _sendExample(String question) {
    if (_typing) return;
    _input
      ..text = question
      ..selection = TextSelection.collapsed(offset: question.length);
    unawaited(_send());
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    if (_typing) return;

    final SIConsoleQueryController controller = ref.read(
      siConsoleQueryControllerProvider,
    );
    if (ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)) {
      await showCrisisDialog(context);
      return;
    }
    final EmotionalSafetyAssessment safety = controller.assessEmotionalSafety(
      text,
    );
    if (safety.requiresSupportivePause) {
      final SupportiveDistressChoice choice =
          await showSupportiveDistressDialog(context);
      if (!mounted ||
          choice != SupportiveDistressChoice.continueWithGentleQuestion) {
        return;
      }
      _input.clear();
      _appendLocalResponse(
        query: text,
        typed: controller.supportiveSafetyResponse(query: text),
        fallbackEmotion: 'balanced',
      );
      return;
    }

    if (_handleLocalShortcut(text)) {
      _input.clear();
      return;
    }
    final List<String> priorUserTurns = _messages
        .where((_Msg message) => message.isUser)
        .map((_Msg message) => message.text.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    _input.clear();

    _safeSetState(() => _messages.add(_Msg(text: text, isUser: true)));
    _scrollToBottom();
    _safeSetState(() => _typing = true);

    await _dispatchQuery(
      text,
      priorUserTurns: priorUserTurns.length <= 4
          ? priorUserTurns
          : priorUserTurns.sublist(priorUserTurns.length - 4),
    );
  }

  bool _handleLocalShortcut(String text) {
    final SIConsoleShortcutInvocation invocation =
        SIConsoleShortcutRegistry.parse(text);
    if (invocation.kind == SIShortcutParseKind.notShortcut) return false;
    if (invocation.kind == SIShortcutParseKind.unknown) {
      _addShortcutFallback(
        query: text,
        response:
            'Unknown shortcut "${invocation.token}". No part of the request was sent or discarded. Use /help to list the available shortcuts.',
        reason: 'unknown_shortcut:${invocation.token.toLowerCase()}',
      );
      return true;
    }

    final SIConsoleShortcutDefinition definition = invocation.definition!;
    final SIV2EvidenceSnapshot? snapshot = ref
        .read(siV2EvidenceSnapshotProvider)
        .asData
        ?.value;

    if (invocation.argumentsRejected) {
      _addShortcutFallback(
        query: text,
        response:
            '${definition.shortcut} does not accept extra text. No argument was ignored or sent. Use ${definition.shortcut} alone. Received: "${invocation.arguments}"',
        reason: 'shortcut_arguments_rejected:${definition.id}',
      );
      return true;
    }

    switch (invocation.resolvedRoute!) {
      case SIShortcutRoute.help:
        _addShortcutResponse(
          query: text,
          definition: definition,
          response:
              '${SIConsoleShortcutRegistry.buildHelp(filter: invocation.arguments)}\n\n'
              'Rules:\n'
              '- Task creation is Creator-only. Use Creator to create tasks.\n'
              '- SI V2 has read-only evidence capability and cannot mutate domain data.\n'
              '- The visible query builder is primary; shortcuts are aliases.\n\n'
              'High-signal SI V2 prompts:\n'
              '- "What needs attention?"\n'
              '- "Why is this goal at risk?"\n'
              '- "Compare my two nearest goals."\n'
              '- "What happens if I defer this task?"\n'
              '- "Which commitments conflict?"\n'
              '- "What would change your recommendation?"',
        );
        return true;
      case SIShortcutRoute.status:
        final String surfaceShortcuts = SIConsoleShortcutRegistry.definitions
            .where(
              (SIConsoleShortcutDefinition item) =>
                  item.route != SIShortcutRoute.help &&
                  item.route != SIShortcutRoute.status,
            )
            .map((SIConsoleShortcutDefinition item) => item.shortcut)
            .join(', ');
        final String status = (snapshot == null)
            ? 'SI STATUS\n\n'
                  'Local data sources are still loading. Retry /status in a second.\n'
                  'No domain data was changed.'
            : 'SI STATUS\n\n'
                  'Read-only Evidence Lens:\n'
                  '- tasks: ${snapshot.tasks.length}\n'
                  '- goals: ${snapshot.goals.length}\n'
                  '- milestones: ${snapshot.milestones.length}\n'
                  '- Timeline: ${snapshot.timeline.length}\n'
                  '- unavailable sources: ${snapshot.unavailableSources.length}\n'
                  '- revision: ${snapshot.revision.substring(0, 16)}\n\n'
                  'Available evidence aliases: $surfaceShortcuts.';

        _addShortcutResponse(
          query: text,
          response: status,
          definition: definition,
        );
        return true;
      case SIShortcutRoute.tasksSnapshot:
      case SIShortcutRoute.goalsSnapshot:
      case SIShortcutRoute.planSnapshot:
      case SIShortcutRoute.milestonesSnapshot:
      case SIShortcutRoute.timelineSnapshot:
      case SIShortcutRoute.trajectorySnapshot:
        return false;
      case SIShortcutRoute.intelligenceQuery:
        return false;
    }
  }

  Future<void> _dispatchQuery(
    String text, {
    required List<String> priorUserTurns,
  }) async {
    final String startingPersonContextRevision = ref.read(
      siV2PersonContextRevisionProvider,
    );
    try {
      final SIV2Query query = SIV2Query.fromUserInput(
        rawText: text,
        selectedIntent: _intent,
        selectedSources: _sources,
        timeRange: _timeRange,
        entityFilter: _entityFilter.text,
        scenarioAssumption: _scenarioAssumption.text,
        priorUserTurns: priorUserTurns,
      );
      final SIV2Response response = await ref
          .read(siV2QueryServiceProvider)
          .analyze(query);
      if (!mounted) return;
      final String currentPersonContextRevision = ref.read(
        siV2PersonContextRevisionProvider,
      );
      if (currentPersonContextRevision != startingPersonContextRevision) {
        _safeSetState(() => _typing = false);
        _invalidatePersonContextDependentResponses(
          currentPersonContextRevision,
          forceNotice: true,
        );
        _scrollToBottom();
        return;
      }
      response.validate();
      _safeSetState(() {
        _typing = false;
        _boundPersonContextRevision = currentPersonContextRevision;
        _messages.add(
          _Msg(
            text: response.toPlainText(),
            isUser: false,
            emotion:
                response.conflicts.any(
                  (SIV2Conflict item) =>
                      item.severity == SIV2ConflictSeverity.critical,
                )
                ? 'cautious'
                : 'focused',
            rationale:
                'SI V2 read-only evidence revision ${response.snapshotRevision.substring(0, 16)}',
            processingMode: AIProcessingMode.onDevice,
            siV2: response,
          ),
        );
      });
      _scrollToLatestResponse();
    } catch (_) {
      if (!mounted) return;
      final AIRecommendation fallback = ref
          .read(siConsoleQueryControllerProvider)
          .localFallbackResponse(
            query: text,
            response:
                'SI V2 could not validate a read-only evidence response. Retry, broaden the Evidence Lens, or select tasks, goals, milestones, or Timeline. Nothing was changed.',
            reason: 'si_v2_contract_or_evidence_failure',
            emotion: 'cautious',
          );
      fallback.contract!.validate();
      _safeSetState(() {
        _typing = false;
        _messages.add(
          _Msg(
            text: fallback.message,
            isUser: false,
            emotion: fallback.emotion ?? 'cautious',
            rationale: fallback.reasoning,
            systemPanel: true,
            processingMode: fallback.processingMode,
          ),
        );
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _scrollToLatestResponse() {
    final int request = ++_latestResponseScrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          request != _latestResponseScrollRequest ||
          !_scroll.hasClients) {
        return;
      }
      final BuildContext? responseContext = _latestResponseKey.currentContext;
      if (responseContext != null) {
        _ensureLatestResponseVisible(responseContext);
        return;
      }

      // A lazily built transcript may not have created the newest bubble yet.
      // Reveal it first, then align the response from its beginning.
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _latestResponseScrollRequest) return;
        final BuildContext? revealedContext = _latestResponseKey.currentContext;
        if (revealedContext != null) {
          _ensureLatestResponseVisible(revealedContext);
        }
      });
    });
  }

  void _ensureLatestResponseVisible(BuildContext responseContext) {
    final MediaQueryData media = MediaQuery.of(context);
    unawaited(
      Scrollable.ensureVisible(
        responseContext,
        alignment: 0.05,
        duration: media.disableAnimations || media.accessibleNavigation
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(siV2PersonContextRevisionProvider, (
      String? previous,
      String next,
    ) {
      _invalidatePersonContextDependentResponses(next);
    });
    final AsyncValue<SIV2EvidenceSnapshot> snapshotAsync = ref.watch(
      siV2EvidenceSnapshotProvider,
    );
    final AsyncValue<bool> availabilityAsync = ref.watch(
      siV2AvailabilityProvider,
    );
    final SIV2EvidenceSnapshot? snapshot = snapshotAsync.asData?.value;
    final Object? consoleError = snapshotAsync.asError?.error;
    final bool consoleAvailable = availabilityAsync.asData?.value ?? false;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final bool keyboardVisible = keyboardInset > 0;
    final double composerBottomInset = keyboardInset > 0
        ? keyboardInset
        : mediaQuery.padding.bottom;

    // The composer's own height isn't known until after it's laid out, so
    // the transcript's reserved bottom padding is measured, not guessed —
    // see _measureComposer.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureComposer());

    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgSiConsole,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                onBack: () {
                  unawaited(ref.read(voiceServiceProvider).stop());
                  goToAppView(context, ref, AppView.nexus);
                },
                onSpeakSummary: _messages.any((_Msg msg) => !msg.isUser)
                    ? () {
                        final List<_Msg> recentAssistant = _messages
                            .where((msg) => !msg.isUser)
                            .toList(growable: false);
                        final List<String> points = recentAssistant.reversed
                            .take(3)
                            .map((msg) => msg.text)
                            .toList(growable: false);
                        unawaited(
                          ref
                              .read(voiceServiceProvider)
                              .speakSummary(
                                title: 'SI console voice summary',
                                points: points,
                              ),
                        );
                      }
                    : null,
                onSpeakAccessibility: () {
                  unawaited(_showAccessibilityGuide());
                },
              ),
              _ContextStatusBanner(
                availabilityLoading: availabilityAsync.isLoading,
                availabilityError: availabilityAsync.asError?.error,
                available: consoleAvailable,
                loading: snapshotAsync.isLoading,
                error: consoleError,
                snapshot: snapshot,
                onRetry: () {
                  ref.invalidate(siV2AvailabilityProvider);
                  ref.invalidate(siV2EvidenceSnapshotProvider);
                },
              ),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: _composerHeight,
                  builder: (context, composerHeight, _) {
                    final double composerReservedHeight = composerHeight;
                    final bool showWelcome = _messages.isEmpty && !_typing;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              composerReservedHeight + composerBottomInset,
                            ),
                            itemCount: showWelcome
                                ? 1
                                : _messages.length + (_typing ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (showWelcome) {
                                return _ConsoleWelcome(
                                  enabled: consoleAvailable,
                                  snapshot: snapshot,
                                  onQuestion: _sendExample,
                                );
                              }
                              if (_typing && i == _messages.length) {
                                return _TypingIndicator(animation: _typingAnim);
                              }
                              final Widget bubble = _BubbleTile(
                                msg: _messages[i],
                                onReport: _messages[i].isUser
                                    ? null
                                    : () => unawaited(
                                        _showReportDialog(_messages[i]),
                                      ),
                              );
                              final bool latestResponse =
                                  i == _messages.length - 1 &&
                                  !_messages[i].isUser;
                              return latestResponse
                                  ? KeyedSubtree(
                                      key: _latestResponseKey,
                                      child: KeyedSubtree(
                                        key: const Key(
                                          'si-latest-response-anchor',
                                        ),
                                        child: bubble,
                                      ),
                                    )
                                  : bubble;
                            },
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: composerBottomInset,
                            ),
                            child: KeyedSubtree(
                              key: _composerKey,
                              child: _InputBar(
                                controller: _input,
                                entityFilterController: _entityFilter,
                                scenarioAssumptionController:
                                    _scenarioAssumption,
                                onSend: _send,
                                compact: keyboardVisible,
                                busy: _typing,
                                enabled: consoleAvailable,
                                intent: _intent,
                                sources: _sources,
                                timeRange: _timeRange,
                                onIntentChanged: (SIV2Intent value) {
                                  setState(() => _intent = value);
                                },
                                onSourceChanged:
                                    (SIV2Source source, bool selected) {
                                      if (!selected && _sources.length == 1) {
                                        return;
                                      }
                                      setState(() {
                                        final Set<SIV2Source> updated = _sources
                                            .toSet();
                                        selected
                                            ? updated.add(source)
                                            : updated.remove(source);
                                        _sources = updated;
                                      });
                                    },
                                onTimeRangeChanged: (SIV2TimeRange value) {
                                  setState(() => _timeRange = value);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
