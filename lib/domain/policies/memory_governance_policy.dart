// CHRONOSPARK-CLASS: SHIPPING | Feature: Governed memory
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/domain/policies/emotional_safety_policy.dart';

final class MemoryGovernanceException implements Exception {
  const MemoryGovernanceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Central fail-closed rules for explicit durable preference memory.
abstract final class MemoryGovernancePolicy {
  static const int maxPreferenceCharacters = 280;
  static const int defaultRetentionDays = 90;
  static const int maxRetentionDays = 365;

  static final RegExp _emotionalDisclosure = RegExp(
    r"\b(i feel|i am anxious|i'm anxious|depressed|hopeless|panic attack|trauma|overwhelmed|grieving|ashamed|terrified|furious|miserable)\b",
    caseSensitive: false,
  );

  static MemorySensitivity classify(String text) {
    final EmotionalSafetyAssessment safety = EmotionalSafetyPolicy.assess(text);
    if (safety.requiresImmediateSafety) {
      return MemorySensitivity.crisis;
    }
    if (safety.requiresSupportivePause || _emotionalDisclosure.hasMatch(text)) {
      return MemorySensitivity.emotional;
    }
    return MemorySensitivity.personal;
  }

  static String validatePreferenceText(String text) {
    final String normalized = text.trim();
    if (normalized.isEmpty) {
      throw const MemoryGovernanceException(
        'empty_memory',
        'Enter the exact preference you want remembered.',
      );
    }
    if (normalized.length > maxPreferenceCharacters) {
      throw const MemoryGovernanceException(
        'memory_too_long',
        'Preferences must be 280 characters or fewer. Raw transcripts are never stored as memory.',
      );
    }
    final MemorySensitivity sensitivity = classify(normalized);
    if (sensitivity == MemorySensitivity.crisis) {
      throw const MemoryGovernanceException(
        'crisis_memory_blocked',
        'Crisis-related text stays ephemeral and cannot be saved as memory.',
      );
    }
    if (sensitivity == MemorySensitivity.emotional) {
      throw const MemoryGovernanceException(
        'emotional_memory_blocked',
        'Raw emotional disclosures stay ephemeral. Rewrite this as a planning-style preference.',
      );
    }
    return normalized;
  }

  static DateTime validateExpiry({
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    final DateTime created = createdAt.toUtc();
    final DateTime expiry = expiresAt.toUtc();
    if (!expiry.isAfter(created) ||
        expiry.difference(created) > const Duration(days: maxRetentionDays)) {
      throw const MemoryGovernanceException(
        'invalid_expiry',
        'Choose an expiry between tomorrow and one year from now.',
      );
    }
    return expiry;
  }
}
