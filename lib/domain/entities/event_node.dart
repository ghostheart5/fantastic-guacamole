class EventNode {
  final String id;
  final String label;
  final DateTime start;
  final DateTime end;
  final bool locked;

  const EventNode({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.locked,
  });
}
