import 'package:fantastic_guacamole/core/storage/account_storage_namespace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountStorageNamespace', () {
    test('V2 is deterministic, versioned, and collision free for known collision', () {
      final aSlash = AccountStorageNamespace.authenticated('a/b');
      final aQuestion = AccountStorageNamespace.authenticated('a?b');

      expect(aSlash.v2Scope, startsWith('v2.'));
      expect(aSlash.v2Scope, isNot(aQuestion.v2Scope));
      expect(aSlash.v2Scope, AccountStorageNamespace.authenticated('a/b').v2Scope);
      expect(aSlash.legacyV1Scope, 'a_b');
      expect(aQuestion.legacyV1Scope, 'a_b');
    });

    test('preserves case and Unicode without replacement collisions', () {
      expect(
        AccountStorageNamespace.authenticated('A').v2Scope,
        isNot(AccountStorageNamespace.authenticated('a').v2Scope),
      );
      expect(
        AccountStorageNamespace.authenticated('Å').v2Scope,
        AccountStorageNamespace.authenticated('Å').v2Scope,
      );
    });

    test('rejects empty and whitespace-altered authenticated identities', () {
      expect(() => AccountStorageNamespace.authenticated(''), throwsArgumentError);
      expect(() => AccountStorageNamespace.authenticated('   '), throwsArgumentError);
      expect(() => AccountStorageNamespace.authenticated(' A '), throwsArgumentError);
    });

    test('keeps signed-out V1 and V2 namespaces distinct', () {
      const AccountStorageNamespace signedOut = AccountStorageNamespace.signedOut();
      expect(signedOut.legacyV1Scope, AccountStorageNamespace.signedOutV1);
      expect(signedOut.v2Scope, AccountStorageNamespace.signedOutV2);
      expect(signedOut.v2Scope, isNot(signedOut.legacyV1Scope));
    });

    test('reproduces existing V1 scoped-key compatibility', () {
      final scope = AccountStorageNamespace.authenticated('user-1');
      expect(scope.scopedKey('profile_state_v2', version: StorageScopeVersion.legacyV1), 'profile_state_v2.user-1');
      expect(scope.scopedKey('ai_learning', version: StorageScopeVersion.legacyV1), 'ai_learning.user-1');
      expect(scope.scopedKey('offline_sync_queue_v1', version: StorageScopeVersion.legacyV1), 'offline_sync_queue_v1.user-1');
    });

    test('never auto-claims ambiguous or signed-out legacy records', () {
      expect(
        AccountStorageNamespace.legacyMigrationEligibility(
          v2Exists: false,
          legacyExists: true,
          ownership: LegacyScopeOwnership.ambiguous,
        ),
        LegacyMigrationEligibility.preserveLegacy,
      );
      expect(
        AccountStorageNamespace.legacyMigrationEligibility(
          v2Exists: false,
          legacyExists: true,
          ownership: LegacyScopeOwnership.unownedSignedOut,
        ),
        LegacyMigrationEligibility.preserveLegacy,
      );
    });

    test('permits only proven-owned copy and never overwrites V2', () {
      expect(
        AccountStorageNamespace.legacyMigrationEligibility(
          v2Exists: false,
          legacyExists: true,
          ownership: LegacyScopeOwnership.provenOwned,
        ),
        LegacyMigrationEligibility.copyAllowed,
      );
      expect(
        AccountStorageNamespace.legacyMigrationEligibility(
          v2Exists: true,
          legacyExists: true,
          ownership: LegacyScopeOwnership.provenOwned,
        ),
        LegacyMigrationEligibility.retainExistingV2,
      );
    });

    test('has no collisions across generated supported identity corpus', () {
      final Set<String> scopes = <String>{};
      final List<String> identities = <String>[
        for (int index = 0; index < 512; index++) 'user/$index?${index * 17}',
        'α',
        'Å',
        'A',
        'a',
      ];
      for (final String identity in identities) {
        expect(scopes.add(AccountStorageNamespace.authenticated(identity).v2Scope), isTrue);
      }
    });
  });
}
