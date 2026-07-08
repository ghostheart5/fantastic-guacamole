import 'package:fantastic_guacamole/state/models/experiment_assignment.dart';
import 'package:fantastic_guacamole/state/providers/feature_flags_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final experimentAssignmentsProvider =
    FutureProvider<List<ExperimentAssignment>>((Ref ref) async {
      return ref.read(featureFlagRepositoryProvider).loadAssignments();
    });

final experimentAssignmentProvider =
    Provider.family<ExperimentAssignment?, String>((
      Ref ref,
      String experimentId,
    ) {
      final AsyncValue<List<ExperimentAssignment>> assignmentsAsync = ref.watch(
        experimentAssignmentsProvider,
      );
      return assignmentsAsync.maybeWhen(
        data: (List<ExperimentAssignment> assignments) {
          for (final ExperimentAssignment assignment in assignments) {
            if (assignment.experimentId == experimentId) {
              return assignment;
            }
          }
          return null;
        },
        orElse: () => null,
      );
    });

final experimentVariantProvider = Provider.family<String, String>((
  Ref ref,
  String experimentId,
) {
  return ref.watch(experimentAssignmentProvider(experimentId))?.variant ??
      'control';
});
