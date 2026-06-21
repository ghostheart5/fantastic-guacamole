class TacticalSequenceEntity {
  final String id;
  final String missionId;
  final List<String> orderedTaskIds;

  const TacticalSequenceEntity({
    required this.id,
    required this.missionId,
    required this.orderedTaskIds,
  });
}
