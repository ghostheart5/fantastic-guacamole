import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/features/flowmap/application/add_flowmap_edge.dart';
import 'package:fantastic_guacamole/features/flowmap/application/add_flowmap_node.dart';
import 'package:fantastic_guacamole/features/flowmap/application/clear_flowmap.dart';
import 'package:fantastic_guacamole/features/flowmap/application/get_flowmap.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_graph_entity.dart';
import 'package:fantastic_guacamole/features/flowmap/domain/flowmap_repository.dart';
import 'package:fantastic_guacamole/features/flowmap/infrastructure/flowmap_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final featureFlowmapRepositoryProvider = Provider<FlowmapRepository>((Ref ref) {
  return FlowmapRepositoryImpl(ref.read(flowmapRepositoryProvider));
});

final featureGetFlowmapUseCaseProvider = Provider<GetFlowmap>((Ref ref) {
  return GetFlowmap(ref.read(featureFlowmapRepositoryProvider));
});

final featureAddFlowmapNodeUseCaseProvider = Provider<AddFlowmapNode>((
  Ref ref,
) {
  return AddFlowmapNode(ref.read(featureFlowmapRepositoryProvider));
});

final featureAddFlowmapEdgeUseCaseProvider = Provider<AddFlowmapEdge>((
  Ref ref,
) {
  return AddFlowmapEdge(ref.read(featureFlowmapRepositoryProvider));
});

final featureClearFlowmapUseCaseProvider = Provider<ClearFlowmap>((Ref ref) {
  return ClearFlowmap(ref.read(featureFlowmapRepositoryProvider));
});

final featureFlowmapGraphProvider =
    NotifierProvider<
      FeatureFlowmapGraphController,
      AsyncValue<FlowmapGraphEntity>
    >(FeatureFlowmapGraphController.new);

class FeatureFlowmapGraphController
    extends Notifier<AsyncValue<FlowmapGraphEntity>> {
  @override
  AsyncValue<FlowmapGraphEntity> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> refresh() {
    return _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final FlowmapGraphEntity graph = await ref
          .read(featureGetFlowmapUseCaseProvider)
          .call();
      state = AsyncValue.data(graph);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
