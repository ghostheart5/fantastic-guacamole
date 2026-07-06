import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/insight_model.dart';
import 'package:fantastic_guacamole/state/models/insights_models.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/flowmap_provider.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/insights_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final insightsServiceProvider = Provider<InsightsService>((Ref ref) => const InsightsService());

final insightsBundleProvider = Provider<InsightsBundle>((Ref ref) {
  return ref.watch(insightsServiceProvider).build(ref.watch(siStateProvider));
});

final insightsActionsProvider = Provider<InsightsActions>((Ref ref) {
  return InsightsActions(ref);
});

final _publishedInsightSignatureProvider =
    NotifierProvider<_PublishedInsightSignatureNotifier, String?>(
      _PublishedInsightSignatureNotifier.new,
    );

class InsightsActions {
  const InsightsActions(this._ref);

  final Ref _ref;

  Future<void> publishBundle(InsightsBundle bundle) async {
    final String signature = _signatureFor(bundle);
    final String? previous = _ref.read(_publishedInsightSignatureProvider);
    if (signature.isEmpty || signature == previous) {
      return;
    }

    final DateTime now = DateTime.now();
    final String summary = bundle.summary.trim().isEmpty
        ? 'System insight generated.'
        : bundle.summary.trim();
    final List<String> topTitles = bundle.items
        .take(3)
        .map((Insight item) => item.title.trim())
        .where((String title) => title.isNotEmpty)
        .toList(growable: false);
    final String memoryText = topTitles.isEmpty ? summary : '$summary :: ${topTitles.join(' | ')}';

    await _ref
        .read(logsActionsProvider)
        .addMirroredEntry(source: 'insight_generated', message: summary);
    await _ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'timeline-insight-${now.microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Insight Generated',
            detail: summary,
            timestamp: now,
          ),
        );
    await _ref
        .read(flowmapProvider.notifier)
        .addNode(
          title: topTitles.isEmpty ? 'Insight Signal' : topTitles.first,
          description: summary,
          tags: const <String>['insight', 'generated'],
        );
    await _ref.read(memoriesActionsProvider).saveMirroredMemory(memoryText);
    _ref.invalidate(soulStateProvider);
    await _refreshCoachDecision();
    _ref.read(eventBusProvider).emit(InsightLifecycleEvent(summary: summary, titles: topTitles));
    _ref.read(_publishedInsightSignatureProvider.notifier).set(signature);
  }

  String _signatureFor(InsightsBundle bundle) {
    final String titles = bundle.items
        .map((Insight item) => '${item.title}|${item.description}')
        .join('::');
    return '${bundle.summary}|${bundle.healthScore.toStringAsFixed(3)}|$titles';
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await _ref.read(generateSiDecisionUseCaseProvider).call();
      _ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Do not block insight publication when coach refresh fails.
    }
  }
}

class _PublishedInsightSignatureNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String value) {
    state = value;
  }
}
