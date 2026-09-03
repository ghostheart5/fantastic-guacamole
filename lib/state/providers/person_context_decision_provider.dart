// CHRONOSPARK-CLASS: SHIPPING | Feature: Governed Nexus decision context
import 'package:fantastic_guacamole/domain/entities/person_context.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Set<PersonContextPurpose> sharedDecisionPersonContextPurposes =
    <PersonContextPurpose>{
      ...operationalPersonContextPurposes,
      PersonContextPurpose.outcomeLearning,
    };

final PersonContextAccessRequest sharedDecisionPersonContextRequest =
    PersonContextAccessRequest(
      surface: PersonContextSurface.nexus,
      purposes: sharedDecisionPersonContextPurposes,
    );

/// Session-only user override for the context bound to the canonical decision.
/// Watching account scope makes the override impossible to carry across users.
final personContextDecisionIgnoredSignalsProvider =
    NotifierProvider<PersonContextDecisionIgnoredSignals, Set<String>>(
      PersonContextDecisionIgnoredSignals.new,
    );

class PersonContextDecisionIgnoredSignals extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(accountStorageScopeProvider);
    return const <String>{};
  }

  void ignoreForNow(Iterable<String> signalIds) {
    final Set<String> normalized = signalIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    state = Set<String>.unmodifiable(<String>{...state, ...normalized});
  }

  void restore() => state = const <String>{};
}
