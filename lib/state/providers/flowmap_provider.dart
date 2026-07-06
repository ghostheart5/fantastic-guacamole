import 'package:fantastic_guacamole/core/eventing/domain_event.dart';
import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/state/controllers/profile_controller.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:fantastic_guacamole/state/providers/event_bus_provider.dart';
import 'package:fantastic_guacamole/state/providers/feature_derived_providers.dart';
import 'package:fantastic_guacamole/state/providers/insights_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final flowmapProvider =
    NotifierProvider<FlowmapController, AsyncValue<List<FlowmapNode>>>(
      FlowmapController.new,
    );

class FlowmapController extends Notifier<AsyncValue<List<FlowmapNode>>> {
  @override
  AsyncValue<List<FlowmapNode>> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final nodes = await ref.read(getFlowmapUseCaseProvider).call();
      if (!ref.mounted) return;
      state = AsyncValue.data(nodes);
    } catch (e, st) {
      if (!ref.mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addNode({
    required String title,
    String? description,
    List<String> tags = const [],
    bool refreshCoach = false,
    bool syncSoulMap = false,
    bool updateInsights = false,
    bool awardProgression = false,
  }) async {
    final String trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    final String? trimmedDescription = description?.trim();
    final node = FlowmapNode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: trimmedTitle,
      description: (trimmedDescription?.isEmpty ?? true)
          ? null
          : trimmedDescription,
      tags: tags,
      createdAt: DateTime.now(),
    );
    await ref.read(updateFlowmapNodeUseCaseProvider).call(node);
    state = AsyncValue.data([...state.asData?.value ?? <FlowmapNode>[], node]);

    if (syncSoulMap) {
      ref.invalidate(soulStateProvider);
    }
    if (updateInsights) {
      ref.invalidate(insightsBundleProvider);
    }
    if (awardProgression) {
      ref.read(profileProvider.notifier).addXP(8);
    }
    if (refreshCoach) {
      await _refreshCoachDecision();
    }
    ref
        .read(eventBusProvider)
        .emit(
          FlowmapLifecycleEvent(
            nodeId: node.id,
            title: node.title,
            action: 'added',
          ),
        );
  }

  Future<void> deleteNode(String id) async {
    await ref.read(deleteFlowmapNodeUseCaseProvider).call(id);
    String deletedTitle = 'Flow node';
    for (final FlowmapNode node in state.asData?.value ?? <FlowmapNode>[]) {
      if (node.id == id) {
        deletedTitle = node.title;
        break;
      }
    }
    final updated = (state.asData?.value ?? <FlowmapNode>[])
        .where((n) => n.id != id)
        .toList();
    state = AsyncValue.data(updated);
    ref
        .read(eventBusProvider)
        .emit(
          FlowmapLifecycleEvent(
            nodeId: id,
            title: deletedTitle,
            action: 'deleted',
          ),
        );
  }

  Future<void> updateNode(FlowmapNode updated) async {
    await ref.read(updateFlowmapNodeUseCaseProvider).call(updated);
    state = AsyncValue.data([
      for (final n in state.asData?.value ?? <FlowmapNode>[])
        if (n.id == updated.id) updated else n,
    ]);
    ref
        .read(eventBusProvider)
        .emit(
          FlowmapLifecycleEvent(
            nodeId: updated.id,
            title: updated.title,
            action: 'updated',
          ),
        );
  }

  Future<void> _refreshCoachDecision() async {
    try {
      await ref.read(generateSiDecisionUseCaseProvider).call();
      ref.invalidate(domainSiDecisionProvider);
    } catch (_) {
      // Avoid blocking flowmap node creation if coach refresh fails.
    }
  }
}
