import 'package:fantastic_guacamole/domain/entities/planner_v2_response.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fantastic_guacamole/l10n/creator_copy.dart';

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
    return CreatorDraftPreview._fromPlannerOption(
      option,
      createdAt: DateTime.now().toUtc(),
    );
  }

  factory CreatorDraftPreview.fromPlannerResponse(
    PlannerV2Response response, {
    DateTime? createdAt,
  }) {
    if (response.isClarification) {
      throw StateError(
        'Clarification must be answered before a Creator draft can be staged.',
      );
    }
    final PlannerOption option = response.recommendedOption;
    final copy = CreatorCopy(response.isSpanish);
    final String evidence = response.verifiedEvidence
        .map((String item) => '- $item')
        .join('\n');
    return CreatorDraftPreview._fromPlannerOption(
      option,
      createdAt: (createdAt ?? DateTime.now()).toUtc(),
      isSpanish: response.isSpanish,
      guidanceContext: copy.draftGuidance(
        response.recommendationReason,
        evidence,
      ),
    );
  }

  factory CreatorDraftPreview._fromPlannerOption(
    PlannerOption option, {
    required DateTime createdAt,
    String? guidanceContext,
    bool isSpanish = false,
  }) {
    final copy = CreatorCopy(isSpanish);
    return CreatorDraftPreview(
      id: 'planner-draft-${createdAt.microsecondsSinceEpoch}',
      title: option.title,
      description:
          '${option.description}\n\n${copy.draftEffort(option.estimatedMinutes, option.tradeoff)}'
          '${guidanceContext == null ? '' : '\n\n$guidanceContext'}',
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

  void stage(CreatorDraftPreview preview) => state = preview;

  void open(CreatorDraftPreview preview) => stage(preview);

  void clear() => state = null;
}
