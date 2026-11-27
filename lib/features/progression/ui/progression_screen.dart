import 'dart:async';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/domain/entities/habit_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/l10n/insights_copy.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/patterns_models.dart';
import 'package:fantastic_guacamole/state/models/progression_state.dart';
import 'package:fantastic_guacamole/state/providers/patterns_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:fantastic_guacamole/ui/navigation/insights_destination_switch.dart';
import 'package:fantastic_guacamole/ui/widgets/plain/plain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

part 'progression_screen.copy.dart';
part 'progression_screen.sections.dart';

enum _ProgressionShareAction { progress, achievement }

/// Patterns: what you recorded, built on the plain kit. Every figure is read
/// from [patternsProvider] (records, or the plan for workload); nothing here
/// is a prediction.
class ProgressionScreen extends ConsumerStatefulWidget {
  const ProgressionScreen({super.key});

  @override
  ConsumerState<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends ConsumerState<ProgressionScreen> {
  /// The ranges Patterns offers (the patterns engine accepts these two).
  static const List<int> _ranges = <int>[7, 30];

  Future<bool> _confirmShare(
    BuildContext context, {
    required String title,
    required String preview,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(
              journeyText(
                context,
                'Review before sharing. This summary contains progress metrics, not your task or note text.\n\n$preview',
                'Revisa antes de compartir. Este resumen contiene métricas de progreso, sin el texto de tus tareas o notas.\n\n$preview',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(journeyText(context, 'Cancel', 'Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(journeyText(context, 'Share', 'Compartir')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _shareProgressCard(BuildContext context) async {
    final profile = ref.read(profileProvider);
    final trajectory = ref.read(trajectorySummaryProvider);
    final String text = journeyText(
      context,
      'Axiomara progress snapshot\n'
          'Level ${profile.level} · ${profile.xp} XP · ${profile.streak}-day streak\n'
          '${trajectory.completedTasks} tasks finished\n'
          'Building steady progress with Axiomara: ${AppUrls.website}',
      'Resumen de progreso de Axiomara\n'
          'Nivel ${profile.level} · ${profile.xp} XP · Racha de ${profile.streak} días\n'
          '${trajectory.completedTasks} tareas terminadas\n'
          'Progresando con Axiomara: ${AppUrls.website}',
    );

    if (!await _confirmShare(
      context,
      title: journeyText(
        context,
        'Review progress snapshot',
        'Revisar resumen de progreso',
      ),
      preview: text,
    )) {
      return;
    }
    if (!context.mounted) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: journeyText(
            context,
            'Axiomara progress snapshot',
            'Resumen de progreso de Axiomara',
          ),
          subject: journeyText(
            context,
            'My Axiomara progress update',
            'Mi actualización de progreso en Axiomara',
          ),
        ),
      );
      AppAnalytics.track(
        'share_progress',
        params: <String, Object?>{'method': 'share_sheet'},
      );
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      AppAnalytics.track(
        'share_progress',
        params: <String, Object?>{'method': 'clipboard_fallback'},
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Share sheet unavailable. Progress snapshot copied to clipboard.',
            'No se puede abrir el menú para compartir. Resumen de progreso copiado al portapapeles.',
          ),
        ),
      ),
    );
  }

  Future<void> _shareAchievementCard(BuildContext context) async {
    final profile = ref.read(profileProvider);
    final String text = journeyText(
      context,
      'Axiomara progress milestone\n'
          'Level ${profile.level} reached\n'
          'Current streak: ${profile.streak} days\n'
          'Build with Axiomara: ${AppUrls.website}',
      'Progreso en Axiomara\n'
          'Nivel ${profile.level} alcanzado\n'
          'Racha actual: ${profile.streak} días\n'
          'Construye con Axiomara: ${AppUrls.website}',
    );

    if (!await _confirmShare(
      context,
      title: journeyText(
        context,
        'Review achievement snapshot',
        'Revisar resumen del logro',
      ),
      preview: text,
    )) {
      return;
    }
    if (!context.mounted) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: journeyText(
            context,
            'Axiomara achievement',
            'Logro de Axiomara',
          ),
          subject: journeyText(
            context,
            'I hit a new Axiomara milestone',
            'Alcancé un nuevo hito en Axiomara',
          ),
        ),
      );
      AppAnalytics.track(
        'share_achievement',
        params: <String, Object?>{'method': 'share_sheet'},
      );
      return;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      AppAnalytics.track(
        'share_achievement',
        params: <String, Object?>{'method': 'clipboard_fallback'},
      );
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Share sheet unavailable. Achievement summary copied to clipboard.',
            'No se puede abrir el menú para compartir. Resumen del logro copiado al portapapeles.',
          ),
        ),
      ),
    );
  }

  /// "Open My plan" when there is open work, "Add something" when there is
  /// none; both record the first Patterns review, as the old advisor action
  /// did.
  void _openPlan({required bool hasWork}) {
    _recordProgressionReview(ref);
    goToAppView(context, ref, hasWork ? AppView.timeline : AppView.creator);
  }

  bool? _inView;

  /// True from the first frame back in view until the re-read has started.
  /// A flag only: no figures are kept in this state.
  bool _rereadPending = false;

  /// True for the whole re-read after coming back into view, so its
  /// "Updating" line is not announced (it is not news to the person).
  bool _resumeRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Out of view (TickerMode off) this screen's subscription is paused, and
    // Riverpod 3 does not rebuild a paused provider when it invalidates
    // itself: a task finished meanwhile would not show. Read again when the
    // screen comes back; its first frame says it is updating instead of
    // showing the old figures as current. (Providers cannot be invalidated
    // during a build, so the read starts right after that frame.)
    final bool inView = TickerMode.valuesOf(context).enabled;
    if (_inView == false && inView && !_rereadPending) {
      _rereadPending = true;
      _resumeRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.invalidate(patternsForAccountProvider);
        setState(() => _rereadPending = false);
      });
    }
    _inView = inView;
  }

  void _retryPatterns() {
    ref.invalidate(patternsForAccountProvider);
    ref.invalidate(patternsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final _PatternsCopy copy = _PatternsCopy.of(context);
    final InsightsCopy names = InsightsCopy.of(context);
    // The only read of Patterns: never copied into this state, so nothing
    // can outlive an account switch. A loading state's value is this
    // account's earlier result.
    final AsyncValue<PatternsResult> patterns = ref.watch(patternsProvider);
    final int rangeDays = ref.watch(patternsRangeDaysProvider);
    final PatternsResult? result = patterns.hasError ? null : patterns.value;
    final bool updating = patterns.isLoading || _rereadPending;
    final bool announceUpdate = updating && !_resumeRead;
    // A plain flag (no figures): the resume re-read ends with its result.
    if (!updating) _resumeRead = false;

    return PlainScreen(
      children: <Widget>[
        PlainHeader(title: names.tabName),
        const SizedBox(height: 12),
        const InsightsDestinationSwitch(current: AppView.progression),
        const SizedBox(height: 12),
        _PageLine(names.patternsSubtitle),
        PlainSection(
          key: const ValueKey<String>('patterns-range'),
          title: copy.timeRange,
          children: <Widget>[
            RangeChoice(
              labels: <String>[
                for (final int days in _ranges) copy.rangeLabel(days),
              ],
              selectedIndex: _ranges.indexOf(rangeDays).clamp(0, 1),
              onSelected: (int index) => ref
                  .read(patternsRangeDaysProvider.notifier)
                  .set(_ranges[index]),
            ),
          ],
        ),
        if (patterns.hasError)
          PlainEmptyState(
            key: const ValueKey<String>('patterns-unreadable'),
            message: copy.unreadable,
            actionLabel: copy.retry,
            onAction: _retryPatterns,
          )
        else if (result == null)
          _Reading(copy.reading)
        else ...<Widget>[
          if (updating) _Updating(copy.updating, announce: announceUpdate),
          _HabitsSection(result: result, copy: copy),
          _TrendSection(result: result, copy: copy),
          _WhenDoneSection(result: result, copy: copy),
          _WorkloadSection(result: result, copy: copy, onOpenPlan: _openPlan),
          _MissedSection(result: result, copy: copy),
        ],
        _LevelSection(
          copy: copy,
          onShare: (_ProgressionShareAction action) async {
            switch (action) {
              case _ProgressionShareAction.progress:
                await _shareProgressCard(context);
              case _ProgressionShareAction.achievement:
                await _shareAchievementCard(context);
            }
          },
        ),
      ],
    );
  }
}

void _recordProgressionReview(WidgetRef ref) {
  unawaited(
    ref
        .read(adaptiveGuidanceProvider.notifier)
        .record(GuidanceMilestone.firstProgressionReview),
  );
}
