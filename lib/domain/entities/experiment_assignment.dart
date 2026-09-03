/// CHRONOSPARK-CLASS: SHIPPING | Feature: Experiment governance
class ExperimentAssignment {
  const ExperimentAssignment({
    required this.experimentId,
    required this.variant,
    required this.bucket,
    this.isControl = false,
  });

  final String experimentId;
  final String variant;
  final int bucket;
  final bool isControl;

  Map<String, Object> toJson() {
    return <String, Object>{
      'experimentId': experimentId,
      'variant': variant,
      'bucket': bucket,
      'isControl': isControl,
    };
  }

  factory ExperimentAssignment.fromJson(Map<String, Object?> json) {
    final String variant = json['variant']?.toString().trim() ?? 'control';
    return ExperimentAssignment(
      experimentId: json['experimentId']?.toString() ?? '',
      variant: variant.isEmpty ? 'control' : variant,
      bucket: (json['bucket'] is num) ? (json['bucket'] as num).toInt() : 0,
      isControl: variant.isEmpty || variant == 'control',
    );
  }
}
