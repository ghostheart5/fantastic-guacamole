import 'dart:async';

import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/features/emotion/widgets/emotion_selector.dart';
import 'package:fantastic_guacamole/features/progression/widgets/progress_bar.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/ai_recommendation.dart';
import 'package:fantastic_guacamole/state/providers/emotion_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/state/emotional_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/crisis_dialog.dart';
import 'package:fantastic_guacamole/ui/widgets/error_boundary_widget.dart';
import 'package:fantastic_guacamole/ui/widgets/holo_button.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SmartPlannerScreen extends ConsumerStatefulWidget {
  const SmartPlannerScreen({super.key});

  @override
  ConsumerState<SmartPlannerScreen> createState() => _SmartPlannerScreenState();
}

class _SmartPlannerScreenState extends ConsumerState<SmartPlannerScreen> {
  double _energy = 0.7;
  EmotionalState _emotion = EmotionalState.neutral;
  late final Future<void> Function(String) _speakVoice;
  late final Future<void> Function() _stopVoice;
  final _notesController = TextEditingController();
  final _followUpController = TextEditingController();
  final _understandingController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _planningGuidanceMessage;
  String? _planningGuidancePrompt;
  PlannerV2Response? _plannerResponse;
  AIProcessingMode _guidanceProcessingMode = AIProcessingMode.unknown;
  List<String> _guidanceEvidence = const <String>[];
  DateTime? _guidanceGeneratedAt;
  String? _followUpError;
  String? _plannerActionStatus;
  final List<_Exchange> _followUps = [];
  bool _saved = false;
  bool _gettingPlanningGuidance = false;
  bool _sendingFollowUp = false;
  bool _editingUnderstanding = false;
  bool _showWhy = false;
  bool _dismissed = false;

  List<_Exchange> get _visibleFollowUps {
    const int maxVisibleFollowUps = 20;
    if (_followUps.length <= maxVisibleFollowUps) {
      return _followUps;
    }
    return _followUps.sublist(_followUps.length - maxVisibleFollowUps);
  }

  @override
  void initState() {
    super.initState();
    final voiceService = ref.read(voiceServiceProvider);
    _speakVoice = voiceService.speak;
    _stopVoice = voiceService.stop;
    _energy = ref.read(siStateProvider).energy;
    _emotion = ref.read(emotionProvider);
  }

  @override
  void dispose() {
    unawaited(_stopVoice());
    _notesController.dispose();
    _followUpController.dispose();
    _understandingController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _getPlanningGuidance() async {
    if (_gettingPlanningGuidance) return;
    try {
      await _doGetPlanningGuidance();
    } catch (e, s) {
      if (mounted) {
        setState(() => _gettingPlanningGuidance = false);
        ErrorBoundary.of(context)?.captureError(e, s);
      }
    }
  }

  Future<void> _doGetPlanningGuidance() async {
    final String notes = _notesController.text.trim();
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    if (planner.detectsCrisis(notes) && mounted) {
      await showCrisisDialog(context);
      return;
    }

    setState(() => _gettingPlanningGuidance = true);

    final SmartPlannerResult result;
    try {
      result = await planner
          .requestPlanningGuidance(
            energy: _energy,
            emotion: _emotion,
            notes: notes,
            history: _conversationHistory(),
            previousSavedNotes: null,
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      if (!mounted) return;
      final SmartPlannerResult fallback = planner.localFallbackResult(
        input: notes.isEmpty ? 'quick check-in' : notes,
        message:
            'Guidance request timed out. Tap GET GUIDANCE again or shorten your input for a faster response.',
        energy: _energy,
        emotion: _emotion,
        history: _conversationHistory(),
        reason: 'request_timeout',
      );
      setState(() {
        _gettingPlanningGuidance = false;
        _planningGuidancePrompt = fallback.prompt;
        _planningGuidanceMessage = fallback.message;
        _plannerResponse = fallback.plannerResponse;
        _understandingController.text = fallback.plannerResponse.whatIHeard;
        _guidanceProcessingMode = fallback.processingMode;
        _guidanceEvidence = fallback.evidence;
        _guidanceGeneratedAt = fallback.generatedAt;
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _planningGuidancePrompt = result.prompt;
      _planningGuidanceMessage = result.message;
      _plannerResponse = result.plannerResponse;
      _understandingController.text = result.plannerResponse.whatIHeard;
      _guidanceProcessingMode = result.processingMode;
      _guidanceEvidence = List<String>.unmodifiable(result.evidence);
      _guidanceGeneratedAt = result.generatedAt;
      _saved = true;
      _gettingPlanningGuidance = false;
      _editingUnderstanding = false;
      _showWhy = false;
      _dismissed = false;
      _plannerActionStatus = null;
    });
    // Speak the planning guidance message
    unawaited(_speakVoice(result.message));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendFollowUp() async {
    if (_sendingFollowUp) return;
    final String text = _followUpController.text.trim();
    if (text.isEmpty) return;
    final SmartPlannerQueryController planner = ref.read(
      smartPlannerQueryControllerProvider,
    );

    if (planner.detectsCrisis(text)) {
      if (!mounted) return;
      await showCrisisDialog(context);
      return;
    }
    _followUpController.clear();
    setState(() {
      _sendingFollowUp = true;
      _followUpError = null;
    });
    try {
      final String reply = await planner
          .requestFollowUp(
            input: text,
            energy: _energy,
            emotion: _emotion,
            reflection: _notesController.text.trim(),
            history: _conversationHistory(),
          )
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;
      setState(() {
        _followUps.add(_Exchange(question: text, answer: reply));
        _sendingFollowUp = false;
      });
      unawaited(_speakVoice(reply));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = 'Follow-up timed out. Retry with a shorter prompt.';
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sendingFollowUp = false;
        _followUpError = 'Follow-up transmit failed. Tap Retry Link.';
      });
      ErrorBoundary.of(context)?.captureError(error, stackTrace);
    }
  }

  void _beginUnderstandingEdit() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null) return;
    _understandingController.text = response.whatIHeard;
    setState(() {
      _editingUnderstanding = true;
      _plannerActionStatus = null;
    });
  }

  void _saveUnderstandingEdit() {
    final PlannerV2Response? response = _plannerResponse;
    final String edited = _understandingController.text.trim();
    if (response == null || edited.isEmpty) return;
    final PlannerV2Response updated = response.copyWith(whatIHeard: edited);
    setState(() {
      _plannerResponse = updated;
      _planningGuidanceMessage = updated.toAccessibleText();
      _editingUnderstanding = false;
      _plannerActionStatus =
          'Understanding updated for this check-in only. Nothing was saved.';
    });
  }

  void _cancelUnderstandingEdit() {
    final PlannerV2Response? response = _plannerResponse;
    if (response != null) {
      _understandingController.text = response.whatIHeard;
    }
    setState(() => _editingUnderstanding = false);
  }

  void _tryThis() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null) return;
    setState(() {
      _plannerActionStatus =
          'Selected “${response.recommendedOption.title}” for this check-in. Nothing was saved.';
    });
  }

  void _makeItSmaller() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null) return;
    final PlannerV2Response updated = response.recommend(
      PlannerOptionKind.minimum,
      why:
          'You asked to make the plan smaller, so the Minimum option is now recommended.',
    );
    setState(() {
      _plannerResponse = updated;
      _planningGuidanceMessage = updated.toAccessibleText();
      _plannerActionStatus =
          'Recommendation reduced locally. Nothing was saved.';
    });
  }

  void _differentApproach() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null) return;
    final PlannerOptionKind alternative = switch (response.recommendedKind) {
      PlannerOptionKind.minimum => PlannerOptionKind.bestFit,
      PlannerOptionKind.bestFit => PlannerOptionKind.stretch,
      PlannerOptionKind.stretch => PlannerOptionKind.minimum,
    };
    final PlannerV2Response updated = response.recommend(
      alternative,
      why:
          'You requested a different approach, so another existing Plan Spectrum option is now recommended.',
    );
    setState(() {
      _plannerResponse = updated;
      _planningGuidanceMessage = updated.toAccessibleText();
      _plannerActionStatus =
          'Alternative selected locally. Review its tradeoff before acting.';
    });
  }

  void _openCreatorDraft() {
    final PlannerV2Response? response = _plannerResponse;
    if (response == null) return;
    ref
        .read(creatorDraftPreviewProvider.notifier)
        .open(
          CreatorDraftPreview.fromPlannerOption(response.recommendedOption),
        );
    goToAppView(context, ref, AppView.creator);
  }

  void _notNow() {
    setState(() {
      _dismissed = true;
      _plannerActionStatus = null;
    });
  }

  Future<void> _rememberPreference() async {
    final TextEditingController preferenceController = TextEditingController();
    int retentionDays = 90;
    bool consentConfirmed = false;
    final _PreferenceMemoryChoice?
    choice = await showDialog<_PreferenceMemoryChoice>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setDialogState) {
          return AlertDialog(
            title: const Text('Remember a Smart Planner preference?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Use only this time is the default. Enter only the exact planning-style preference you want stored; your check-in, emotion, and response are not copied.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('planner-memory-preference-field'),
                    controller: preferenceController,
                    maxLength: 280,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Exact preference',
                      hintText:
                          'Example: Prefer one small next step before optional stretch ideas.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    key: const Key('planner-memory-expiry'),
                    initialValue: retentionDays,
                    decoration: const InputDecoration(
                      labelText: 'Automatically delete after',
                    ),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(value: 30, child: Text('30 days')),
                      DropdownMenuItem(value: 90, child: Text('90 days')),
                      DropdownMenuItem(value: 180, child: Text('180 days')),
                      DropdownMenuItem(value: 365, child: Text('1 year')),
                    ],
                    onChanged: (int? value) {
                      if (value == null) return;
                      setDialogState(() => retentionDays = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.memoryAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Receipt preview\nWhy: adapt future Smart Planner guidance to this preference\nSource: Smart Planner only\nExpiry: $retentionDays days\nControls: view, correct, export, delete in Settings',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('planner-memory-consent'),
                    contentPadding: EdgeInsets.zero,
                    value: consentConfirmed,
                    title: const Text(
                      'I explicitly consent to storing this exact preference.',
                    ),
                    onChanged: (bool? value) =>
                        setDialogState(() => consentConfirmed = value ?? false),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Use only this time'),
              ),
              FilledButton(
                key: const Key('planner-confirm-memory'),
                onPressed: consentConfirmed
                    ? () => Navigator.of(dialogContext).pop(
                        _PreferenceMemoryChoice(
                          text: preferenceController.text,
                          retentionDays: retentionDays,
                        ),
                      )
                    : null,
                child: const Text('Remember preference'),
              ),
            ],
          );
        },
      ),
    );
    preferenceController.dispose();
    if (choice == null || !mounted) {
      if (choice == null && mounted) {
        setState(() {
          _plannerActionStatus =
              'Used only for this check-in. No durable memory was saved.';
        });
      }
      return;
    }

    final DateTime expiresAt = DateTime.now().toUtc().add(
      Duration(days: choice.retentionDays),
    );
    try {
      final MemoryReceipt receipt = await ref
          .read(memoryGovernanceControllerProvider)
          .rememberPreference(
            text: choice.text,
            sourceSurface: MemorySurface.smartPlanner,
            expiresAt: expiresAt,
            consentConfirmed: true,
            whyStored:
                'Adapt future Smart Planner guidance to this explicit planning-style preference.',
            provenance: 'User-entered in Smart Planner memory consent dialog.',
          );
      if (!mounted) return;
      final String expiry = receipt.expiresAt!
          .toLocal()
          .toIso8601String()
          .split('T')
          .first;
      setState(() {
        _plannerActionStatus =
            'Preference remembered with consent. Smart Planner only · expires $expiry · manage in Settings.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _plannerActionStatus = error.toString());
    }
  }

  List<Map<String, String>> _conversationHistory() {
    final List<Map<String, String>> history = <Map<String, String>>[];
    final String initialPrompt = _planningGuidancePrompt?.trim() ?? '';
    final String initialResponse = _planningGuidanceMessage?.trim() ?? '';
    if (initialPrompt.isNotEmpty) {
      history.add(<String, String>{'role': 'user', 'content': initialPrompt});
    }
    if (initialResponse.isNotEmpty) {
      history.add(<String, String>{
        'role': 'assistant',
        'content': initialResponse,
      });
    }
    for (final _Exchange exchange in _followUps) {
      history
        ..add(<String, String>{'role': 'user', 'content': exchange.question})
        ..add(<String, String>{
          'role': 'assistant',
          'content': exchange.answer,
        });
    }
    return history.length > 8 ? history.sublist(history.length - 8) : history;
  }

  @override
  Widget build(BuildContext context) {
    final PlannerV2Response? plannerResponse = _plannerResponse;
    final String effectivePlannerMessage =
        plannerResponse?.toAccessibleText() ?? '';
    final bool hasPlannerMessage = plannerResponse != null && !_dismissed;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgHome,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    hasPlannerMessage ? 20 : 12,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 4),
                    const _DisclaimerText(),
                    const SizedBox(height: 12),
                    const _ProgressionBanner(),
                    const SizedBox(height: 12),
                    const _QuickNavRow(),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          goToAppView(context, ref, AppView.creator),
                      child: const Text('OPEN CREATOR TO MAKE TASK'),
                    ),
                    const SizedBox(height: 14),
                    _PlannerPanel(
                      label: 'ENERGY',
                      accentColor: AppColors.neonCyan,
                      child: _EnergySlider(
                        value: _energy,
                        color: AppColors.neonCyan,
                        onChanged: (v) => setState(() {
                          _energy = v;
                          _saved = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlannerPanel(
                      label: 'EMOTIONAL STATE',
                      accentColor: AppColors.neonViolet,
                      child: EmotionSelector(
                        selected: _emotion,
                        onSelect: (e) => setState(() {
                          _emotion = e;
                          _saved = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlannerPanel(
                      label: 'PLANNING CONTEXT',
                      accentColor: AppColors.neonViolet,
                      child: TextField(
                        key: const Key('planner-context-field'),
                        controller: _notesController,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Planning context',
                          helperText:
                              'Used only for this check-in unless you explicitly remember a preference.',
                          hintText:
                              'Share your current context, friction, or desired outcome...',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) {
                          if (_saved) {
                            setState(() => _saved = false);
                          }
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Check-in input stays ephemeral. Getting guidance does not save a reflection, change SI state, or create a plan.',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    HoloButton(
                      label: _gettingPlanningGuidance
                          ? 'THINKING...'
                          : (_saved ? 'REFRESH GUIDANCE' : 'GET GUIDANCE'),
                      color: AppColors.neonCyan,
                      onTap: _gettingPlanningGuidance
                          ? null
                          : _getPlanningGuidance,
                    ),
                    if (hasPlannerMessage) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label: 'Planning guidance ready',
                        child: _PlannerV2ResponsePanel(
                          response: plannerResponse,
                          understandingController: _understandingController,
                          editingUnderstanding: _editingUnderstanding,
                          showWhy: _showWhy,
                          actionStatus: _plannerActionStatus,
                          onBeginEdit: _beginUnderstandingEdit,
                          onSaveEdit: _saveUnderstandingEdit,
                          onCancelEdit: _cancelUnderstandingEdit,
                          onTryThis: _tryThis,
                          onMakeSmaller: _makeItSmaller,
                          onDifferentApproach: _differentApproach,
                          onToggleWhy: () =>
                              setState(() => _showWhy = !_showWhy),
                          onOpenCreatorDraft: _openCreatorDraft,
                          onRememberPreference: () =>
                              unawaited(_rememberPreference()),
                          onNotNow: _notNow,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GuidanceEvidence(
                        mode: _guidanceProcessingMode,
                        evidence: _guidanceEvidence,
                        generatedAt: _guidanceGeneratedAt,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _VoiceButton(message: effectivePlannerMessage),
                          _VoiceSummaryButton(
                            headline: effectivePlannerMessage,
                            energy: _energy,
                            emotion: _emotion,
                          ),
                          const _VoiceAccessibilityButton(),
                          _MicButton(
                            onRecognized: (String text) =>
                                _followUpController.text = text,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._visibleFollowUps.map(
                        (ex) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _bubble(ex.question, isUser: true),
                              const SizedBox(height: 6),
                              _bubble(ex.answer, isUser: false),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: hasPlannerMessage
            ? AnimatedPadding(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: _FollowUpBar(
                  controller: _followUpController,
                  onSend: _sendFollowUp,
                  sending: _sendingFollowUp,
                  errorText: _followUpError,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        SmartPressable(
          onTap: () => goToAppView(context, ref, AppView.nexus),
          semanticLabel: 'Back',
          child: const Padding(
            padding: EdgeInsets.all(11),
            child: Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.neonCyan, AppColors.neonViolet],
                ).createShader(bounds),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SMART PLANNER',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Text(
                'EVIDENCE-AWARE PLANNING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(String text, {required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.neonViolet.withValues(alpha: 0.18)
              : AppColors.neonCyan.withValues(alpha: 0.10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.neonViolet.withValues(alpha: 0.35)
                : AppColors.neonCyan.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF9BE7FF),
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _Exchange {
  const _Exchange({required this.question, required this.answer});
  final String question;
  final String answer;
}

class _PreferenceMemoryChoice {
  const _PreferenceMemoryChoice({
    required this.text,
    required this.retentionDays,
  });

  final String text;
  final int retentionDays;
}

class _PlannerV2ResponsePanel extends StatelessWidget {
  const _PlannerV2ResponsePanel({
    required this.response,
    required this.understandingController,
    required this.editingUnderstanding,
    required this.showWhy,
    required this.onBeginEdit,
    required this.onSaveEdit,
    required this.onCancelEdit,
    required this.onTryThis,
    required this.onMakeSmaller,
    required this.onDifferentApproach,
    required this.onToggleWhy,
    required this.onOpenCreatorDraft,
    required this.onRememberPreference,
    required this.onNotNow,
    this.actionStatus,
  });

  final PlannerV2Response response;
  final TextEditingController understandingController;
  final bool editingUnderstanding;
  final bool showWhy;
  final String? actionStatus;
  final VoidCallback onBeginEdit;
  final VoidCallback onSaveEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onTryThis;
  final VoidCallback onMakeSmaller;
  final VoidCallback onDifferentApproach;
  final VoidCallback onToggleWhy;
  final VoidCallback onOpenCreatorDraft;
  final VoidCallback onRememberPreference;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return _PlannerPanel(
      label: 'PLANNER V2',
      accentColor: AppColors.memoryAmber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.neonCyan.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'ON-DEVICE PLANNER V2 · DETERMINISTIC · NOT AI-GENERATED',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _section(
            'WHAT I HEARD · EDITABLE',
            editingUnderstanding
                ? Column(
                    children: [
                      TextField(
                        key: const Key('planner-what-i-heard-field'),
                        controller: understandingController,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          helperText: 'Check-in-only edit; nothing is saved.',
                          helperStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: onSaveEdit,
                            child: const Text('Save check-in edit'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: onCancelEdit,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Text(
                    response.whatIHeard,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
          ),
          _section('WHAT APPEARS TO MATTER MOST', _body(response.mattersMost)),
          _section(
            'VERIFIED CHRONOSPARK EVIDENCE',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: response.verifiedEvidence
                  .map(
                    (String item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• $item',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          _section(
            'PLAN SPECTRUM',
            Column(
              children: response.options
                  .map(
                    (PlannerOption option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlanSpectrumOptionCard(
                        option: option,
                        recommended: option.kind == response.recommendedKind,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          _section(
            'RECOMMENDED OPTION + TRADEOFF',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  response.recommendedOption.title,
                  style: const TextStyle(
                    color: AppColors.memoryAmber,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                _body(response.recommendationReason),
                const SizedBox(height: 5),
                _body('Tradeoff: ${response.recommendedOption.tradeoff}'),
              ],
            ),
          ),
          _section('ONE CONCRETE NEXT STEP', _body(response.nextStep)),
          if (response.usefulQuestion?.trim().isNotEmpty ?? false)
            _section('ONE USEFUL QUESTION', _body(response.usefulQuestion!)),
          _section(
            'ADAPTATION RECEIPT',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _body(
                  'Inputs used: ${response.adaptationReceipt.energyPercent}% energy and '
                  '${response.adaptationReceipt.userSelectedEmotion.name} emotion — both selected by you.',
                ),
                const SizedBox(height: 6),
                ...response.adaptationReceipt.adjustments.map(
                  (String item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _body('• $item'),
                  ),
                ),
              ],
            ),
          ),
          if (showWhy)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.memoryAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _body(
                'Why this: ${response.recommendationReason} The recommendation only changes this check-in response; it does not mutate ChronoSpark data.',
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: onTryThis,
                child: const Text('Try this'),
              ),
              OutlinedButton(onPressed: onBeginEdit, child: const Text('Edit')),
              OutlinedButton(
                onPressed: onMakeSmaller,
                child: const Text('Make it smaller'),
              ),
              OutlinedButton(
                onPressed: onDifferentApproach,
                child: const Text('Different approach'),
              ),
              OutlinedButton(
                onPressed: onToggleWhy,
                child: const Text('Why this?'),
              ),
              OutlinedButton(
                key: const Key('planner-open-creator-draft'),
                onPressed: onOpenCreatorDraft,
                child: const Text('Open as Creator draft'),
              ),
              OutlinedButton(
                key: const Key('planner-remember-preference'),
                onPressed: onRememberPreference,
                child: const Text('Remember a preference'),
              ),
              TextButton(onPressed: onNotNow, child: const Text('Not now')),
            ],
          ),
          if (actionStatus != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              label: actionStatus ?? '',
              child: ExcludeSemantics(
                child: Text(
                  actionStatus ?? '',
                  style: const TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.memoryAmber,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  static Widget _body(String text) => Text(
    text,
    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
  );
}

class _PlanSpectrumOptionCard extends StatelessWidget {
  const _PlanSpectrumOptionCard({
    required this.option,
    required this.recommended,
  });

  final PlannerOption option;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final String label = switch (option.kind) {
      PlannerOptionKind.minimum => 'MINIMUM',
      PlannerOptionKind.bestFit => 'BEST-FIT',
      PlannerOptionKind.stretch => 'STRETCH',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: recommended
            ? AppColors.neonCyan.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: recommended
              ? AppColors.neonCyan.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '$label · ${option.estimatedMinutes} MIN',
                style: TextStyle(
                  color: recommended ? AppColors.neonCyan : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              if (recommended)
                const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: AppColors.neonCyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            option.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            option.description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpBar extends StatelessWidget {
  const _FollowUpBar({
    required this.controller,
    required this.onSend,
    required this.sending,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC0B111C),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (errorText != null)
              Semantics(
                liveRegion: true,
                label: 'Follow-up failed. $errorText',
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.recallRed,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: AppColors.recallRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: sending ? null : onSend,
                        child: const Text('Retry follow-up'),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('planner-follow-up-field'),
                    controller: controller,
                    enabled: !sending,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!sending) onSend();
                    },
                    decoration: InputDecoration(
                      labelText: 'Follow-up question',
                      hintText: 'Send a follow-up question...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A2440),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: sending ? 'Sending message' : 'Send message',
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  color: AppColors.neonCyan,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerPanel extends StatelessWidget {
  const _PlannerPanel({
    required this.label,
    required this.child,
    required this.accentColor,
  });

  final String label;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2,
                height: 14,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EnergySlider extends StatelessWidget {
  const _EnergySlider({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            const Text(
              'CURRENT ENERGY',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Current energy',
          value: '${(value * 100).round()} percent',
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: color,
              inactiveTrackColor: Colors.white12,
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value,
              onChanged: onChanged,
              semanticFormatterCallback: (double sliderValue) =>
                  '${(sliderValue * 100).round()} percent',
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceButton extends ConsumerWidget {
  const _VoiceButton({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Read full planning guidance aloud',
      button: true,
      child: GestureDetector(
        onTap: () => unawaited(ref.read(voiceServiceProvider).speak(message)),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.memoryAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.memoryAmber.withValues(alpha: 0.4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_up_rounded,
                color: AppColors.memoryAmber,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'SPEAK',
                style: TextStyle(
                  color: AppColors.memoryAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceSummaryButton extends ConsumerWidget {
  const _VoiceSummaryButton({
    required this.headline,
    required this.energy,
    required this.emotion,
  });

  final String headline;
  final double energy;
  final EmotionalState emotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Read condensed planning summary aloud',
      button: true,
      child: GestureDetector(
        onTap: () => unawaited(
          ref
              .read(voiceServiceProvider)
              .speakSummary(
                title: 'Smart Planner voice summary',
                points: <String>[
                  'Energy is ${(energy * 100).round()} percent',
                  'Emotion state is ${emotion.name}',
                  headline,
                ],
              ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.neonCyan.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.45),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.summarize_rounded,
                color: AppColors.neonCyan,
                size: 15,
              ),
              SizedBox(width: 6),
              Text(
                'SUMMARY',
                style: TextStyle(
                  color: AppColors.neonCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceAccessibilityButton extends ConsumerWidget {
  const _VoiceAccessibilityButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Open Smart Planner accessibility guide and read it aloud',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: const Color(0xFF0D1420),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (BuildContext context) {
              return const SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'A11Y means accessibility. Use these controls for easier reading and audio guidance.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
          unawaited(
            ref
                .read(voiceServiceProvider)
                .speakAccessibilityHint(
                  surface: 'Smart Planner',
                  controls: const <String>[
                    'Adjust energy slider to set intensity',
                    'Select emotional state to tune guidance',
                    'Use Get Guidance to generate a planning response',
                    'Use the speak button to read the latest guidance aloud',
                    'Use summary button for condensed voice recap',
                    'Use microphone button for voice interactions',
                  ],
                ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                color: Colors.white70,
                size: 15,
              ),
              SizedBox(width: 5),
              Text(
                'ACCESS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends ConsumerWidget {
  const _MicButton({required this.onRecognized});

  final ValueChanged<String> onRecognized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final VoiceState voice = ref.watch(voiceControllerProvider);
    final bool listening = voice.isListening;

    // Recognized speech populates the follow-up box for explicit review and
    // send - it is never auto-sent or routed as an action.
    ref.listen<VoiceState>(voiceControllerProvider, (previous, next) {
      final bool stoppedListening =
          (previous?.isListening ?? false) && !next.isListening;
      if (stoppedListening && next.recognizedText.trim().isNotEmpty) {
        onRecognized(next.recognizedText.trim());
        ref.read(voiceControllerProvider.notifier).clearRecognizedText();
      }
    });

    return Semantics(
      label: listening ? 'Stop voice input' : 'Start voice input',
      button: true,
      liveRegion: listening,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (listening) {
            await ref.read(voiceControllerProvider.notifier).stopListening();
            return;
          }
          await ref.read(voiceControllerProvider.notifier).startListening();
          if (!context.mounted) {
            return;
          }
          final String? error = ref.read(voiceControllerProvider).error;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Voice input is unavailable. Check permission and retry.',
                ),
              ),
            );
          }
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: listening
                ? AppColors.neonCyan.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: listening
                  ? AppColors.neonCyan.withValues(alpha: 0.6)
                  : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                listening ? Icons.mic : Icons.mic_none_rounded,
                color: listening ? AppColors.neonCyan : Colors.white54,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                listening ? 'LISTENING...' : 'SPEAK',
                style: TextStyle(
                  color: listening ? AppColors.neonCyan : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Progression banner ───────────────────────────────────────────────────────

class _ProgressionBanner extends ConsumerWidget {
  const _ProgressionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressionProvider).progress;
    final int pct = (progress.levelProgress * 100).round();
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final Widget levelBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.memoryAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.memoryAmber.withValues(alpha: 0.4)),
      ),
      child: Text(
        'LVL ${progress.level}',
        style: const TextStyle(
          color: AppColors.memoryAmber,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
    final Widget streak = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.local_fire_department,
          color: Colors.deepOrangeAccent,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          '${progress.streak}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    final List<Widget> progressLabels = <Widget>[
      Text(
        '$pct% to Level ${progress.level + 1}',
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
      Text(
        '${progress.xpToNext} XP',
        style: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    ];
    final Widget progressDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (textScale > 1.3)
          ...progressLabels
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: progressLabels,
          ),
        const SizedBox(height: 4),
        ProgressBar(
          value: progress.levelProgress,
          color: AppColors.memoryAmber,
          height: 4,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.memoryAmber.withValues(alpha: 0.35),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool reflow = constraints.maxWidth < 420 || textScale > 1.3;
          if (reflow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[levelBadge, streak],
                ),
                const SizedBox(height: 8),
                progressDetails,
              ],
            );
          }
          return Row(
            children: <Widget>[
              levelBadge,
              const SizedBox(width: 12),
              Expanded(child: progressDetails),
              const SizedBox(width: 12),
              streak,
            ],
          );
        },
      ),
    );
  }
}

// ─── Quick nav row ───────────────────────────────────────────────────────────

class _QuickNavRow extends ConsumerWidget {
  const _QuickNavRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _QuickNavCard(
          label: 'GOALS',
          icon: Icons.flag_rounded,
          color: AppColors.memoryAmber,
          onTap: () => goToAppView(context, ref, AppView.goals),
        ),
        const SizedBox(width: 8),
        _QuickNavCard(
          label: 'TIMELINE',
          icon: Icons.timeline_rounded,
          color: AppColors.neonViolet,
          onTap: () => goToAppView(context, ref, AppView.timeline),
        ),
      ],
    );
  }
}

class _QuickNavCard extends StatelessWidget {
  const _QuickNavCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Open $label',
        onTap: onTap,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Disclaimer ───────────────────────────────────────────────────────────────

class _GuidanceEvidence extends StatelessWidget {
  const _GuidanceEvidence({
    required this.mode,
    required this.evidence,
    required this.generatedAt,
  });

  final AIProcessingMode mode;
  final List<String> evidence;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final String source = switch (mode) {
      AIProcessingMode.external => 'EXTERNAL MODEL RESPONSE',
      AIProcessingMode.onDevice => 'ON-DEVICE PLANNER · NOT AI-GENERATED',
      AIProcessingMode.onDeviceFallback =>
        'ON-DEVICE PLANNER FALLBACK · NOT AI-GENERATED',
      AIProcessingMode.unknown => 'SOURCE UNVERIFIED',
    };
    final DateTime? timestamp = generatedAt;
    final int? ageMinutes = timestamp == null
        ? null
        : DateTime.now().difference(timestamp).inMinutes;
    final String freshness = ageMinutes == null
        ? 'time unavailable'
        : ageMinutes < 5
        ? 'generated now'
        : 'generated ${ageMinutes}m ago';
    return Semantics(
      label: 'Guidance source and evidence',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          <String>[
            '$source • $freshness',
            if (evidence.isNotEmpty) 'Evidence: ${evidence.join(' • ')}',
            'Guidance is advisory; you choose whether to apply it.',
          ].join('\n'),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _DisclaimerText extends StatelessWidget {
  const _DisclaimerText();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Planning guidance is not medical, nutrition, exercise, or mental-health care. For persistent, severe, worsening, or urgent symptoms, contact a qualified professional or local emergency support.',
      style: TextStyle(
        color: Colors.white30,
        fontSize: 10,
        letterSpacing: 0.3,
        height: 1.4,
      ),
    );
  }
}
