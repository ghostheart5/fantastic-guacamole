import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final creatorDraftPreviewProvider =
    NotifierProvider<CreatorDraftPreviewNotifier, CreatorDraftPreview?>(
      CreatorDraftPreviewNotifier.new,
    );

final class CreatorDraftPreview {
  CreatorDraftPreview({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.sourceOption,
    required DateTime createdAt,
  }) : createdAt = createdAt.toUtc();

  factory CreatorDraftPreview.fromPlannerOption(PlannerOption option) {
    final DateTime createdAt = DateTime.now().toUtc();
    return CreatorDraftPreview(
      id: 'planner-draft-${createdAt.microsecondsSinceEpoch}',
      title: option.title,
      description:
          '${option.description}\n\nEstimated effort: ${option.estimatedMinutes} minutes. '
          'Planner tradeoff: ${option.tradeoff}',
      estimatedMinutes: option.estimatedMinutes,
      sourceOption: option.kind,
      createdAt: createdAt,
    );
  }

  final String id;
  final String title;
  final String description;
  final int estimatedMinutes;
  final PlannerOptionKind sourceOption;
  final DateTime createdAt;
}

class CreatorDraftPreviewNotifier extends Notifier<CreatorDraftPreview?> {
  @override
  CreatorDraftPreview? build() => null;

  void open(CreatorDraftPreview preview) => state = preview;

  void clear() => state = null;
}
