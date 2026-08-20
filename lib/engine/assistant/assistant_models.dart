import 'dart:collection';

import 'package:fantastic_guacamole/domain/entities/assistant_contracts.dart';
import 'package:fantastic_guacamole/domain/entities/assistant_conversation_scope.dart';

final class AssistantIntent {
  AssistantIntent({
    required String label,
    required this.confidence,
    required this.surface,
    required String group,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : label = label.trim(),
       group = group.trim(),
       metadata = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.from(metadata),
       ) {
    validate();
  }

  final String label;
  final double confidence;
  final AssistantSurface surface;
  final String group;
  final Map<String, Object?> metadata;

  void validate() {
    if (label.isEmpty || group.isEmpty) {
      throw const AssistantContractException(
        'Assistant intents require a label and group.',
      );
    }
    if (!confidence.isFinite || confidence < 0 || confidence > 1) {
      throw const AssistantContractException(
        'Assistant intent confidence must be between zero and one.',
      );
    }
    validateAssistantJsonObject(metadata, path: 'intent.metadata');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'confidence': confidence,
    'surfaceId': surface.storageId,
    'group': group,
    'metadata': metadata,
  };

  factory AssistantIntent.fromJson(Map<String, Object?> json) {
    final Set<String> expected = <String>{
      'label',
      'confidence',
      'surfaceId',
      'group',
      'metadata',
    };
    if (json.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(json.keys.toSet()).isNotEmpty) {
      throw const AssistantContractException('Invalid assistant intent shape.');
    }
    final Object? label = json['label'];
    final Object? confidence = json['confidence'];
    final Object? surface = json['surfaceId'];
    final Object? group = json['group'];
    final Object? metadata = json['metadata'];
    if (label is! String ||
        confidence is! num ||
        surface is! String ||
        group is! String ||
        metadata is! Map<Object?, Object?>) {
      throw const AssistantContractException('Invalid assistant intent value.');
    }
    return AssistantIntent(
      label: label,
      confidence: confidence.toDouble(),
      surface: AssistantSurface.fromStorageId(surface),
      group: group,
      metadata: Map<String, Object?>.from(metadata),
    );
  }
}

final class AssistantContext {
  AssistantContext({
    required this.surface,
    required this.intent,
    required String query,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : query = query.trim(),
       metadata = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.from(metadata),
       ) {
    validate();
  }

  final AssistantSurface surface;
  final AssistantIntent intent;
  final String query;
  final Map<String, Object?> metadata;

  void validate() {
    intent.validate();
    if (query.isEmpty || intent.surface != surface) {
      throw const AssistantContractException(
        'Assistant context must contain a query for the same surface.',
      );
    }
    validateAssistantJsonObject(metadata, path: 'context.metadata');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'surfaceId': surface.storageId,
    'intent': intent.toJson(),
    'query': query,
    'metadata': metadata,
  };

  factory AssistantContext.fromJson(Map<String, Object?> json) {
    final Set<String> expected = <String>{
      'surfaceId',
      'intent',
      'query',
      'metadata',
    };
    if (json.keys.toSet().difference(expected).isNotEmpty ||
        expected.difference(json.keys.toSet()).isNotEmpty) {
      throw const AssistantContractException(
        'Invalid assistant context shape.',
      );
    }
    final Object? surface = json['surfaceId'];
    final Object? intent = json['intent'];
    final Object? query = json['query'];
    final Object? metadata = json['metadata'];
    if (surface is! String ||
        intent is! Map<Object?, Object?> ||
        query is! String ||
        metadata is! Map<Object?, Object?>) {
      throw const AssistantContractException(
        'Invalid assistant context value.',
      );
    }
    return AssistantContext(
      surface: AssistantSurface.fromStorageId(surface),
      intent: AssistantIntent.fromJson(Map<String, Object?>.from(intent)),
      query: query,
      metadata: Map<String, Object?>.from(metadata),
    );
  }
}
