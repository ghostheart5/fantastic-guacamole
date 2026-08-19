import 'dart:convert';

import 'package:fantastic_guacamole/data/local/hive_storage.dart';
import 'package:fantastic_guacamole/domain/entities/plan_entity.dart';
import 'package:fantastic_guacamole/domain/entities/plan_proposal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/time_block.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_plan_repository.dart';

class PlanRepository implements IPlanRepository {
  PlanRepository(this._store);

  final HiveStorage<String> _store;

  @override
  Future<PlanEntity?> getPlan(DateTime date) async {
    await _store.open();
    final String? raw = _store.get(_dateKey(date));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return _fromJson(decoded);
  }

  @override
  Future<void> savePlan(PlanEntity plan) async {
    await _store.put(_dateKey(plan.date), jsonEncode(_toJson(plan)));
  }

  @override
  Future<PlanProposalEntity?> getProposal(String id) async {
    await _store.open();
    final String? raw = _store.get(_proposalKey(id));
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return _proposalFromJson(decoded);
  }

  @override
  Future<void> saveProposal(PlanProposalEntity proposal) {
    return _store.put(
      _proposalKey(proposal.id),
      jsonEncode(_proposalToJson(proposal)),
    );
  }

  @override
  Future<void> applyProposal({
    required PlanProposalEntity proposal,
    required PlanEntity plan,
  }) async {
    final PlanProposalEntity? previous = await getProposal(proposal.id);
    await saveProposal(proposal);
    try {
      await savePlan(plan);
    } on Object {
      if (previous != null) await saveProposal(previous);
      rethrow;
    }
  }

  static String _dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _proposalKey(String id) => 'proposal:$id';

  static PlanEntity _fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawBlocks =
        json['blocks'] as List<dynamic>? ?? const <dynamic>[];
    return PlanEntity(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      blocks: rawBlocks
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> block) => TimeBlock(
              id: block['id'] as String? ?? '',
              taskId: block['taskId'] as String? ?? '',
              title: block['title'] as String? ?? 'Untitled',
              start:
                  DateTime.tryParse(block['start'] as String? ?? '') ??
                  DateTime.now(),
              end:
                  DateTime.tryParse(block['end'] as String? ?? '') ??
                  DateTime.now().add(const Duration(minutes: 30)),
              completed: block['completed'] as bool? ?? false,
            ),
          )
          .toList(growable: false),
    );
  }

  static Map<String, dynamic> _toJson(PlanEntity plan) {
    return <String, dynamic>{
      'id': plan.id,
      'date': plan.date.toIso8601String(),
      'updatedAt': (plan.updatedAt ?? DateTime.now()).toIso8601String(),
      'blocks': plan.blocks
          .map(
            (TimeBlock block) => <String, dynamic>{
              'id': block.id,
              'taskId': block.taskId,
              'title': block.title,
              'start': block.start.toIso8601String(),
              'end': block.end.toIso8601String(),
              'completed': block.completed,
            },
          )
          .toList(growable: false),
    };
  }

  static PlanProposalEntity _proposalFromJson(Map<String, dynamic> json) {
    final List<dynamic> rawBlocks =
        json['blocks'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> rawConflicts =
        json['conflicts'] as List<dynamic>? ?? const <dynamic>[];
    return PlanProposalEntity(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      generatedAt:
          DateTime.tryParse(json['generatedAt']?.toString() ?? '') ??
          DateTime.now(),
      status: PlanProposalStatus.values.firstWhere(
        (PlanProposalStatus status) =>
            status.name == json['status']?.toString(),
        orElse: () => PlanProposalStatus.preview,
      ),
      blocks: rawBlocks
          .whereType<Map<String, dynamic>>()
          .map(_blockFromJson)
          .toList(growable: false),
      conflicts: rawConflicts
          .whereType<Map<String, dynamic>>()
          .map(PlanConflict.fromJson)
          .toList(growable: false),
      evidenceSources:
          (json['evidenceSources'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic value) => value.toString())
              .toList(growable: false),
      sourceDecisionId: json['sourceDecisionId']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      resolvedAt: DateTime.tryParse(json['resolvedAt']?.toString() ?? ''),
    );
  }

  static Map<String, dynamic> _proposalToJson(PlanProposalEntity proposal) =>
      <String, dynamic>{
        'id': proposal.id,
        'date': proposal.date.toIso8601String(),
        'generatedAt': proposal.generatedAt.toIso8601String(),
        'status': proposal.status.name,
        'blocks': proposal.blocks.map(_blockToJson).toList(growable: false),
        'conflicts': proposal.conflicts
            .map((PlanConflict conflict) => conflict.toJson())
            .toList(growable: false),
        'evidenceSources': proposal.evidenceSources,
        'sourceDecisionId': proposal.sourceDecisionId,
        'rejectionReason': proposal.rejectionReason,
        'resolvedAt': proposal.resolvedAt?.toIso8601String(),
      };

  static TimeBlock _blockFromJson(Map<String, dynamic> block) {
    final DateTime start =
        DateTime.tryParse(block['start']?.toString() ?? '') ?? DateTime.now();
    return TimeBlock(
      id: block['id']?.toString() ?? '',
      taskId: block['taskId']?.toString() ?? '',
      title: block['title']?.toString() ?? 'Untitled',
      start: start,
      end:
          DateTime.tryParse(block['end']?.toString() ?? '') ??
          start.add(const Duration(minutes: 30)),
      completed:
          block['completed'] as bool? ?? block['isCompleted'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _blockToJson(TimeBlock block) =>
      <String, dynamic>{
        'id': block.id,
        'taskId': block.taskId,
        'title': block.title,
        'start': block.start.toIso8601String(),
        'end': block.end.toIso8601String(),
        'completed': block.completed,
      };
}
