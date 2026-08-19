import 'package:fantastic_guacamole/domain/entities/milestone_entity.dart';
import 'package:fantastic_guacamole/domain/interfaces/i_milestone_repository.dart';
import 'package:fantastic_guacamole/domain/usecases/milestone_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

class _MilestoneRepository implements IMilestoneRepository {
  List<MilestoneEntity> milestones = <MilestoneEntity>[];

  @override
  Future<List<MilestoneEntity>> getMilestones() async =>
      List<MilestoneEntity>.of(milestones);

  @override
  Future<void> saveMilestones(List<MilestoneEntity> values) async {
    milestones = List<MilestoneEntity>.of(values);
  }
}

void main() {
  final DateTime now = DateTime.utc(2026, 8, 19, 12);
  late _MilestoneRepository repository;

  setUp(() => repository = _MilestoneRepository());

  test('create validates identity and persists canonical metadata', () async {
    expect(await CreateMilestone(repository)(title: ' ', now: now), isNull);

    final MilestoneEntity? milestone = await CreateMilestone(repository)(
      title: '  Beta ready  ',
      id: 'm1',
      now: now,
      targetDate: now.add(const Duration(days: 7)),
      priority: MilestonePriority.high,
    );

    expect(milestone?.title, 'Beta ready');
    expect(milestone?.priority, MilestonePriority.high);
    expect(await GetMilestones(repository)(), hasLength(1));
  });

  test('progress, completion, archive, and delete are durable', () async {
    await CreateMilestone(repository)(title: 'Beta', id: 'm1', now: now);
    final MilestoneEntity? progressed = await UpdateMilestoneProgress(
      repository,
    )('m1', 45, now: now.add(const Duration(hours: 1)));
    final MilestoneEntity? completed = await CompleteMilestone(repository)(
      'm1',
      reflection: 'Done well',
      now: now.add(const Duration(hours: 2)),
    );
    final MilestoneEntity? archived = await ArchiveMilestone(repository)(
      'm1',
      now: now.add(const Duration(hours: 3)),
    );

    expect(progressed?.status, MilestoneStatus.inProgress);
    expect(completed?.completionPercent, 100);
    expect(completed?.reflection, 'Done well');
    expect(archived?.status, MilestoneStatus.archived);
    expect(await DeleteMilestone(repository)('m1'), isTrue);
    expect(await GetMilestones(repository)(), isEmpty);
  });
}
