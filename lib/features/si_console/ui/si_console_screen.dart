import 'dart:async';
import 'dart:math' as math;

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:fantastic_guacamole/domain/entities/si_v2_contract.dart';
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
  // Starting guess only, replaced by the composer's real measured height
  // right after the first frame — see _measureComposer.
  final ValueNotifier<double> _composerHeight = ValueNotifier<double>(220);
  bool _typing = false;
  SIV2Intent _intent = SIV2Intent.answer;
  Set<SIV2Source> _sources = SIV2Source.values.toSet();
  SIV2TimeRange _timeRange = SIV2TimeRange.thirtyDays;
  late final AnimationController _typingAnim;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final voiceService = ref.read(voiceServiceProvider);
    _stopVoice = voiceService.stop;
    _speakAccessibilityHint = voiceService.speakAccessibilityHint;
    _messages.add(
      const _Msg(
        text:
            'SI V2 is ready. Analysis uses a read-only Evidence Lens over tasks, goals, milestones, and Timeline. Every substantive answer separates facts, calculations, inferences, scenarios, conflicts, confidence anatomy, and evidence links.',
        isUser: false,
        emotion: 'confident',
        systemPanel: true,
      ),
    );
    _typingAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
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
              title: const Text('Report AI response'),
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
    _scrollToBottom();
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    if (_typing) return;

    if (ref.read(siConsoleQueryControllerProvider).detectsCrisis(text)) {
      showCrisisDialog(context);
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

    _dispatchQuery(
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
      response.validate();
      _safeSetState(() {
        _typing = false;
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
      _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SIV2EvidenceSnapshot> snapshotAsync = ref.watch(
      siV2EvidenceSnapshotProvider,
    );
    final SIV2EvidenceSnapshot? snapshot = snapshotAsync.asData?.value;
    final Object? consoleError = snapshotAsync.asError?.error;
    final String? engineSnapshot = snapshot == null
        ? null
        : 'Read-only lens: ${snapshot.tasks.length} tasks, ${snapshot.goals.length} goals, ${snapshot.milestones.length} milestones, ${snapshot.timeline.length} Timeline events';
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
                engineSnapshot: engineSnapshot,
                onSpeakSummary: () {
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
                },
                onSpeakAccessibility: () {
                  unawaited(_showAccessibilityGuide());
                },
              ),
              _ContextStatusBanner(
                loading: snapshotAsync.isLoading,
                error: consoleError,
                snapshot: snapshot,
                onRetry: () => ref.invalidate(siV2EvidenceSnapshotProvider),
              ),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: _composerHeight,
                  builder: (context, composerHeight, _) {
                    final double composerReservedHeight = composerHeight;
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
                            itemCount: _messages.length + (_typing ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (_typing && i == _messages.length) {
                                return _TypingIndicator(animation: _typingAnim);
                              }
                              return _BubbleTile(
                                msg: _messages[i],
                                onReport: _messages[i].isUser
                                    ? null
                                    : () => unawaited(
                                        _showReportDialog(_messages[i]),
                                      ),
                              );
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

class _ContextStatusBanner extends StatelessWidget {
  const _ContextStatusBanner({
    required this.loading,
    required this.error,
    required this.snapshot,
    required this.onRetry,
  });

  final bool loading;
  final Object? error;
  final SIV2EvidenceSnapshot? snapshot;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;
    final Color accent;
    if (error != null) {
      message = PublicFailure.from(
        error!,
        fallback:
            'Strategic context is temporarily unavailable. Saved work is unchanged.',
      ).message;
      icon = Icons.error_outline_rounded;
      accent = Colors.amberAccent;
    } else if (loading) {
      message = 'Initializing SI context...';
      icon = Icons.sync_rounded;
      accent = AppColors.neonCyan;
    } else {
      message = snapshot == null
          ? 'Evidence state unavailable.'
          : 'Read-only evidence ready: ${snapshot!.tasks.length} tasks, ${snapshot!.goals.length} goals, ${snapshot!.milestones.length} milestones, ${snapshot!.timeline.length} Timeline events. ${_personContextBoundary(snapshot!)}';
      icon = Icons.verified_rounded;
      accent = Colors.greenAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.withValues(alpha: 0.82),
        border: Border(
          bottom: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: message,
              child: ExcludeSemantics(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry evidence loading'),
            ),
          ],
        ],
      ),
    );
  }
}

String _personContextBoundary(SIV2EvidenceSnapshot snapshot) {
  final SIV2PersonContextEvidence? context = snapshot.personContext;
  if (context == null) {
    return 'Person context: unavailable; not used for answers.';
  }
  if (context.isEmpty) {
    return 'Person context: shared but empty; not used for answers.';
  }
  return 'Person context: ${context.signals.length} user-reported ${context.signals.length == 1 ? 'item' : 'items'}, provenance only; not used for answers or answer evidence.';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.onSpeakSummary,
    required this.onSpeakAccessibility,
    this.engineSnapshot,
  });
  final VoidCallback onBack;
  final VoidCallback onSpeakSummary;
  final VoidCallback onSpeakAccessibility;
  final String? engineSnapshot;

  @override
  Widget build(BuildContext context) {
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                label: 'Back to Nexus',
                button: true,
                onTap: onBack,
                child: IconButton(
                  tooltip: 'Back to Nexus',
                  onPressed: onBack,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TemporalScreenHeader(
                  title: 'SI Console V2',
                  subtitle: largeText
                      ? null
                      : 'Systems intelligence · source-aware guidance',
                  eyebrow: largeText ? null : 'Evidence trace',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: 'Read summary',
                  onPressed: onSpeakSummary,
                  color: AppColors.neonCyan,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  tooltip: 'Accessibility guide',
                  onPressed: onSpeakAccessibility,
                  color: Colors.white70,
                  icon: const Icon(Icons.accessibility_new_rounded),
                ),
              ),
            ],
          ),
          if (engineSnapshot != null && !largeText) ...[
            const SizedBox(height: 8),
            TemporalStatusRow(
              icon: Icons.shield_outlined,
              text: engineSnapshot ?? '',
              color: AppColors.neonCyan,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _BubbleTile extends ConsumerWidget {
  const _BubbleTile({required this.msg, this.onReport});
  final _Msg msg;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isUser = msg.isUser;
    final String? emotion = msg.emotion;
    final bool systemPanel = msg.systemPanel && !isUser;
    final Color bubbleColor = isUser
        ? AppColors.neonViolet.withValues(alpha: 0.16)
        : AppColors.bgSecondary.withValues(alpha: 0.9);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _SIAvatar(emotion: msg.emotion),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  liveRegion: !isUser,
                  label: isUser ? 'Your query' : 'SI response',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUser
                            ? Colors.purple.withValues(alpha: 0.25)
                            : systemPanel
                            ? Colors.white24
                            : AppColors.neonCyan.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser && emotion != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: _EmotionTag(emotion: emotion),
                          ),
                        if (!isUser &&
                            msg.processingMode != AIProcessingMode.unknown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _ProcessingModeTag(mode: msg.processingMode),
                          ),
                        if (msg.siV2 case final SIV2Response response)
                          _SIV2ResponseCard(response: response)
                        else
                          TypingText(
                            msg.text,
                            key: ValueKey<String>(
                              'si-msg-${msg.isUser}-${msg.text}',
                            ),
                            animate: false,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: isUser ? Colors.white70 : Colors.white,
                              fontFamily: null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isUser && msg.rationale != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        if (msg.rationale != null &&
                            msg.rationale!.trim().isNotEmpty)
                          'Why this appears: ${msg.rationale!.trim()}',
                      ].join('\n'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (!isUser) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Semantics(
                        button: true,
                        label: 'Read response aloud',
                        child: TextButton.icon(
                          onPressed: () => unawaited(
                            ref.read(voiceServiceProvider).speak(msg.text),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 16),
                          label: const Text('SPEAK'),
                        ),
                      ),
                      if (onReport != null)
                        Semantics(
                          button: true,
                          label: 'Report response',
                          child: TextButton.icon(
                            onPressed: onReport,
                            icon: const Icon(Icons.flag_outlined, size: 16),
                            label: const Text('REPORT'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SIV2ResponseCard extends StatelessWidget {
  const _SIV2ResponseCard({required this.response});

  final SIV2Response response;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('si-v2-response'),
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _section('DIRECT ANSWER', <String>[response.directAnswer]),
          _section(
            'OBSERVED FACTS',
            response.observedFacts
                .map((SIV2Statement item) => item.text)
                .toList(),
          ),
          _section(
            'DETERMINISTIC CALCULATIONS',
            response.calculations
                .map((SIV2Statement item) => item.text)
                .toList(),
          ),
          _section(
            'INFERENCES',
            response.inferences.map((SIV2Statement item) => item.text).toList(),
          ),
          _section('MISSING OR CONFLICTING INFORMATION', <String>[
            ...response.missingInformation,
            ...response.conflicts.map(
              (SIV2Conflict item) =>
                  '${item.severity.name.toUpperCase()}: ${item.summary}',
            ),
          ]),
          _section(
            'SCENARIOS',
            response.scenarios
                .map(
                  (SIV2Scenario item) =>
                      '${item.label}: ${item.projectedEffect}',
                )
                .toList(),
          ),
          _section('SCENARIO ASSUMPTIONS', response.scenarioAssumptions),
          _section('RECOMMENDATION', <String>[response.recommendation]),
          _section('CONFIDENCE ANATOMY', <String>[
            'Evidence strength: ${response.confidence.strength.name}',
            'Coverage: ${response.confidence.coveredSignals} of ${response.confidence.requiredSignals} required signals',
            'Freshness: ${response.confidence.freshness.name}',
            'Conflicts: ${response.confidence.conflictCount}',
            'Assumptions: ${response.confidence.assumptionCount}',
          ]),
          _section(
            'EVIDENCE LINKS',
            response.evidenceLinks
                .map((SIV2EvidenceLink item) => '${item.label} — ${item.uri}')
                .toList(),
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<String> values, {
    double bottomPadding = 14,
  }) {
    final List<String> visible = values
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
    final Color accent = switch (title) {
      'OBSERVED FACTS' => AppColors.neonCyan,
      'DETERMINISTIC CALCULATIONS' => AppColors.neonViolet,
      'INFERENCES' ||
      'SCENARIOS' ||
      'SCENARIO ASSUMPTIONS' => AppColors.memoryAmber,
      'MISSING OR CONFLICTING INFORMATION' => AppColors.recallRed,
      _ => AppColors.neonCyan,
    };
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (visible.isEmpty)
              const Text(
                'None identified.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                  letterSpacing: 0,
                ),
              )
            else
              ...visible.map(
                (String item) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    visible.length == 1 ? item : '• $item',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.45,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SIAvatar extends StatelessWidget {
  const _SIAvatar({this.emotion});
  final String? emotion;

  Color get _color {
    switch (emotion) {
      case 'engaged':
        return Colors.blueAccent;
      case 'confident':
        return Colors.cyanAccent;
      case 'driven':
        return Colors.deepOrangeAccent;
      case 'cautious':
        return Colors.amberAccent;
      case 'strained':
        return Colors.redAccent;
      default:
        return AppColors.neonCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1520),
          border: Border.all(color: _color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: _color.withValues(alpha: 0.25), blurRadius: 8),
          ],
        ),
        child: Center(
          child: Text(
            'SI',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0,
              color: _color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmotionTag extends StatelessWidget {
  const _EmotionTag({required this.emotion});
  final String emotion;

  Color get _color {
    switch (emotion) {
      case 'engaged':
        return Colors.blueAccent;
      case 'confident':
        return Colors.cyanAccent;
      case 'driven':
        return Colors.deepOrangeAccent;
      case 'cautious':
        return Colors.amberAccent;
      case 'strained':
        return Colors.redAccent;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        emotion.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          letterSpacing: 0,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProcessingModeTag extends StatelessWidget {
  const _ProcessingModeTag({required this.mode});

  final AIProcessingMode mode;

  String get _label {
    switch (mode) {
      case AIProcessingMode.external:
        return 'External AI';
      case AIProcessingMode.onDevice:
        return 'On device';
      case AIProcessingMode.onDeviceFallback:
        return 'On-device fallback';
      case AIProcessingMode.unknown:
        return 'Processing unknown';
    }
  }

  Color get _color {
    switch (mode) {
      case AIProcessingMode.external:
        return Colors.deepPurpleAccent;
      case AIProcessingMode.onDevice:
        return Colors.greenAccent;
      case AIProcessingMode.onDeviceFallback:
        return Colors.amberAccent;
      case AIProcessingMode.unknown:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Processing mode: $_label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF07111C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _color.withValues(alpha: 0.55)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'SI is analyzing the current evidence',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const _SIAvatar(),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.18),
                  ),
                ),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (_, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final double phase = (animation.value - i * 0.2).clamp(
                          0.0,
                          1.0,
                        );
                        final double opacity =
                            0.3 + 0.7 * math.sin(phase * math.pi);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.neonCyan,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
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
// Input bar
// ---------------------------------------------------------------------------

ButtonStyle _siSegmentedStyle(Color accent) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 48)),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textStyle: const WidgetStatePropertyAll<TextStyle>(
      TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0),
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      return states.contains(WidgetState.selected)
          ? AppColors.background
          : Colors.white70;
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      return states.contains(WidgetState.selected)
          ? accent
          : AppColors.bgSecondary.withValues(alpha: 0.9);
    }),
    side: WidgetStatePropertyAll<BorderSide>(
      BorderSide(color: accent.withValues(alpha: 0.42)),
    ),
  );
}

class _InputBar extends ConsumerWidget {
  const _InputBar({
    required this.controller,
    required this.entityFilterController,
    required this.scenarioAssumptionController,
    required this.onSend,
    required this.intent,
    required this.sources,
    required this.timeRange,
    required this.onIntentChanged,
    required this.onSourceChanged,
    required this.onTimeRangeChanged,
    this.compact = false,
    this.busy = false,
  });
  final TextEditingController controller;
  final TextEditingController entityFilterController;
  final TextEditingController scenarioAssumptionController;
  final VoidCallback onSend;
  final SIV2Intent intent;
  final Set<SIV2Source> sources;
  final SIV2TimeRange timeRange;
  final ValueChanged<SIV2Intent> onIntentChanged;
  final void Function(SIV2Source source, bool selected) onSourceChanged;
  final ValueChanged<SIV2TimeRange> onTimeRangeChanged;
  final bool compact;
  final bool busy;

  void _insertShortcut(String shortcut) {
    controller
      ..text = '$shortcut '
      ..selection = TextSelection.collapsed(offset: shortcut.length + 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;

    // Recognized speech populates the query box for explicit review and
    // send - it is never auto-sent or routed as a shortcut.
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if (stoppedListening && next.recognizedText.trim().isNotEmpty) {
        controller.text = next.recognizedText.trim();
        ref.read(voiceControllerProvider.notifier).clearRecognizedText();
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool forceCompact =
            constraints.hasBoundedHeight && constraints.maxHeight < 150;
        final bool effectiveCompact = compact || forceCompact;

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            effectiveCompact ? 8 : 10,
            16,
            effectiveCompact ? 10 : 16,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF07111C),
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!effectiveCompact) ...[
                  const Text(
                    'SI V2 QUERY BUILDER',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 10,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<SIV2Intent>(
                      segments: SIV2Intent.values
                          .map(
                            (SIV2Intent option) => ButtonSegment<SIV2Intent>(
                              value: option,
                              label: Text(
                                option.label,
                                key: ValueKey<String>(
                                  'si-v2-intent-${option.name}',
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      selected: <SIV2Intent>{intent},
                      showSelectedIcon: false,
                      style: _siSegmentedStyle(AppColors.neonCyan),
                      onSelectionChanged: busy
                          ? null
                          : (Set<SIV2Intent> selection) =>
                                onIntentChanged(selection.first),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<SIV2Source>(
                      segments: SIV2Source.values
                          .map(
                            (SIV2Source source) => ButtonSegment<SIV2Source>(
                              value: source,
                              label: Text(
                                source.label,
                                key: ValueKey<String>(
                                  'si-v2-source-${source.name}',
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      selected: sources,
                      showSelectedIcon: false,
                      multiSelectionEnabled: true,
                      emptySelectionAllowed: false,
                      style: _siSegmentedStyle(AppColors.neonViolet),
                      onSelectionChanged: busy
                          ? null
                          : (Set<SIV2Source> selection) {
                              for (final SIV2Source source
                                  in SIV2Source.values) {
                                final bool selected = selection.contains(
                                  source,
                                );
                                if (selected != sources.contains(source)) {
                                  onSourceChanged(source, selected);
                                }
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<SIV2TimeRange>(
                      segments: SIV2TimeRange.values
                          .map(
                            (SIV2TimeRange option) =>
                                ButtonSegment<SIV2TimeRange>(
                                  value: option,
                                  label: Text(
                                    option.label,
                                    key: ValueKey<String>(
                                      'si-v2-range-${option.name}',
                                    ),
                                  ),
                                ),
                          )
                          .toList(growable: false),
                      selected: <SIV2TimeRange>{timeRange},
                      showSelectedIcon: false,
                      style: _siSegmentedStyle(AppColors.memoryAmber),
                      onSelectionChanged: busy
                          ? null
                          : (Set<SIV2TimeRange> selection) =>
                                onTimeRangeChanged(selection.first),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints fields) {
                      final bool stackFields =
                          fields.maxWidth < 600 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3;
                      final Widget entityField = TextField(
                        key: const Key('si-v2-entity-filter'),
                        controller: entityFilterController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Entity filter (optional)',
                          labelStyle: TextStyle(color: AppColors.neonCyan),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.neonCyan,
                          ),
                        ),
                      );
                      final Widget assumptionField = TextField(
                        key: const Key('si-v2-assumption'),
                        controller: scenarioAssumptionController,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Scenario assumption (optional)',
                          labelStyle: TextStyle(color: AppColors.neonCyan),
                          floatingLabelStyle: TextStyle(
                            color: AppColors.neonCyan,
                          ),
                        ),
                      );
                      if (stackFields) {
                        return Column(
                          children: <Widget>[
                            entityField,
                            const SizedBox(height: 8),
                            assumptionField,
                          ],
                        );
                      }
                      return Row(
                        children: <Widget>[
                          Expanded(child: entityField),
                          const SizedBox(width: 8),
                          Expanded(child: assumptionField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  PopupMenuButton<SIConsoleShortcutDefinition>(
                    key: const Key('si-v2-power-alias-menu'),
                    enabled: !busy,
                    tooltip: 'Choose a power alias',
                    color: const Color(0xFF0A1520),
                    onSelected: (SIConsoleShortcutDefinition definition) =>
                        _insertShortcut(definition.shortcut),
                    itemBuilder: (BuildContext context) =>
                        SIConsoleShortcutRegistry.chips
                            .map(
                              (SIConsoleShortcutDefinition definition) =>
                                  PopupMenuItem<SIConsoleShortcutDefinition>(
                                    value: definition,
                                    child: Text(definition.shortcut),
                                  ),
                            )
                            .toList(growable: false),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1520),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.34),
                        ),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.terminal_rounded,
                            size: 18,
                            color: AppColors.neonCyan,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'POWER ALIASES',
                              style: TextStyle(
                                color: AppColors.neonCyan,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: Color(0xFFAEB9D0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final List<SIConsoleShortcutDefinition> suggestions =
                        SIConsoleShortcutRegistry.autocomplete(value.text);
                    if (suggestions.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestions
                            .map(
                              (definition) => OutlinedButton(
                                key: ValueKey<String>(
                                  'si-shortcut-autocomplete-${definition.id}',
                                ),
                                onPressed: busy
                                    ? null
                                    : () =>
                                          _insertShortcut(definition.shortcut),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(definition.shortcut),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    );
                  },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('si-query-input'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !busy,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        cursorColor: AppColors.neonCyan,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'SI query',
                          labelStyle: const TextStyle(
                            color: AppColors.neonCyan,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: AppColors.neonCyan,
                          ),
                          hintText: 'Ask SI V2 about current evidence...',
                          hintStyle: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0A1520),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.neonCyan.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!busy) onSend();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: listening
                          ? 'Stop voice input'
                          : 'Start voice input',
                      button: true,
                      enabled: !busy,
                      liveRegion: listening,
                      child: GestureDetector(
                        onTap: busy
                            ? null
                            : () async {
                                if (listening) {
                                  await ref
                                      .read(voiceControllerProvider.notifier)
                                      .stopListening();
                                  return;
                                }
                                await ref
                                    .read(voiceControllerProvider.notifier)
                                    .startListening();
                              },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: listening
                                ? AppColors.neonCyan.withValues(alpha: 0.22)
                                : busy
                                ? const Color(0xFF151B22)
                                : const Color(0xFF102436),
                            border: Border.all(
                              color: busy ? Colors.white12 : AppColors.neonCyan,
                            ),
                          ),
                          child: Icon(
                            listening ? Icons.mic : Icons.mic_none_rounded,
                            color: busy ? Colors.white38 : AppColors.neonCyan,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: busy ? 'SI is analyzing' : 'Send SI query',
                      button: true,
                      enabled: !busy,
                      child: GestureDetector(
                        onTap: busy ? null : onSend,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: busy
                                ? const Color(0xFF151B22)
                                : const Color(0xFF102436),
                            border: Border.all(
                              color: busy ? Colors.white12 : AppColors.neonCyan,
                            ),
                          ),
                          child: Icon(
                            busy
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                            color: busy ? Colors.white38 : AppColors.neonCyan,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
