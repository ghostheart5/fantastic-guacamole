import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/timeline_event_entity.dart';
import 'package:fantastic_guacamole/state/controllers/si_state_controller.dart';
import 'package:fantastic_guacamole/state/models/signal_model.dart';
import 'package:fantastic_guacamole/state/models/signals_models.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/logs_provider.dart';
import 'package:fantastic_guacamole/state/providers/timeline_provider.dart';
import 'package:fantastic_guacamole/state/services/signals_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final signalsServiceProvider = Provider<SignalsService>(
  (Ref ref) => const SignalsService(),
);

final signalsBundleProvider = Provider<SignalsBundle>((Ref ref) {
  return ref.watch(signalsServiceProvider).build(ref.watch(siStateProvider));
});

final signalsActionsProvider = Provider<SignalsActions>((Ref ref) {
  return SignalsActions(ref);
});

final _publishedSignalSignatureProvider =
    NotifierProvider<_PublishedSignalSignatureNotifier, String?>(
      _PublishedSignalSignatureNotifier.new,
    );

void invalidateSignalPublicationState(Ref ref) {
  ref.invalidate(_publishedSignalSignatureProvider);
}

class SignalsActions {
  const SignalsActions(this._ref);

  final Ref _ref;

  Future<void> publishBundle(SignalsBundle bundle) async {
    final String signature = _signatureFor(bundle);
    final String? previous = _ref.read(_publishedSignalSignatureProvider);
    if (signature.isEmpty || signature == previous) {
      return;
    }

    final DateTime now = DateTime.now();
    final String summary = bundle.summary.trim().isEmpty
        ? 'System signal generated.'
        : bundle.summary.trim();
    final List<String> topTitles = bundle.items
        .take(3)
        .map((Signal item) => item.title.trim())
        .where((String title) => title.isNotEmpty)
        .toList(growable: false);
    await _ref
        .read(logsActionsProvider)
        .addMirroredEntry(source: 'signal_generated', message: summary);
    await _ref
        .read(timelineActionsProvider)
        .addMirroredEvent(
          TimelineEventEntity(
            id: 'timeline-signal-${now.microsecondsSinceEpoch}',
            type: TimelineEventType.reflection,
            title: 'Signal Generated',
            detail: summary,
            timestamp: now,
          ),
        );
    _ref.invalidate(soulStateProvider);
    await _refreshPlannerDecision();
    _ref
        .read(eventBusProvider)
        .emit(SignalLifecycleEvent(summary: summary, titles: topTitles));
    _ref.read(_publishedSignalSignatureProvider.notifier).set(signature);
  }

  String _signatureFor(SignalsBundle bundle) {
    final String titles = bundle.items
        .map((Signal item) => '${item.title}|${item.description}')
        .join('::');
    return '${bundle.summary}|${bundle.healthScore.toStringAsFixed(3)}|$titles';
  }

  Future<void> _refreshPlannerDecision() async {
    try {
      await _ref.read(generateSiDecisionUseCaseProvider).call();
      _ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Do not block signal publication when planner refresh fails.
    }
  }
}

class _PublishedSignalSignatureNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String value) {
    state = value;
  }
}
