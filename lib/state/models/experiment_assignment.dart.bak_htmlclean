import 'package:flutter/foundation.dart';

@immutable
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
    return ExperimentAssignment(
      experimentId: json['experimentId']?.toString() ?? '',
      variant: json['variant']?.toString() ?? 'control',
      bucket: (json['bucket'] is num) ? (json['bucket'] as num).toInt() : 0,
      isControl: json['isControl'] == true,
    );
  }
}
