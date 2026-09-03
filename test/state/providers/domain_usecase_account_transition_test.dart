import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/data/di/repositories_providers.dart';
import 'package:fantastic_guacamole/state/providers/account_storage_scope_provider.dart';
import 'package:fantastic_guacamole/state/providers/domain_usecase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final NotifierProvider<_ScopeNotifier, AccountStorageScope> _scopeProvider =
    NotifierProvider<_ScopeNotifier, AccountStorageScope>(_ScopeNotifier.new);

void main() {
  test(
    'account-scoped repositories and their domain use cases rotate together',
    () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          accountStorageScopeProvider.overrideWith(
            (Ref ref) => ref.watch(_scopeProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final Object firstHabitRepository = container.read(
        domainHabitRepositoryProvider,
      );
      final Object firstGetHabits = container.read(getHabitsUseCaseProvider);
      final Object firstCreateHabit = container.read(
        createHabitUseCaseProvider,
      );
      final Object firstToggleHabit = container.read(
        toggleHabitUseCaseProvider,
      );
      final Object firstUpdateHabit = container.read(
        updateHabitUseCaseProvider,
      );
      final Object firstDeleteHabit = container.read(
        deleteHabitUseCaseProvider,
      );
      final Object firstSaveHabits = container.read(saveHabitsUseCaseProvider);
      final Object firstNoteRepository = container.read(
        domainNoteRepositoryProvider,
      );
      final Object firstGetNotes = container.read(getNotesUseCaseProvider);
      final Object firstCreateNote = container.read(createNoteUseCaseProvider);
      final Object firstUpdateNote = container.read(updateNoteUseCaseProvider);
      final Object firstArchiveNote = container.read(
        archiveNoteUseCaseProvider,
      );
      final Object firstDeleteNote = container.read(deleteNoteUseCaseProvider);
      final Object firstIdentityRepository = container.read(
        identityRepositoryProvider,
      );
      final Object firstFirebaseBridgeRepository = container.read(
        firebaseSupabaseBridgeRepositoryProvider,
      );

      container
          .read(_scopeProvider.notifier)
          .setScope(AccountStorageScope.authenticated('account-b'));

      expect(
        container.read(domainHabitRepositoryProvider),
        isNot(same(firstHabitRepository)),
      );
      expect(
        container.read(getHabitsUseCaseProvider),
        isNot(same(firstGetHabits)),
      );
      expect(
        container.read(createHabitUseCaseProvider),
        isNot(same(firstCreateHabit)),
      );
      expect(
        container.read(toggleHabitUseCaseProvider),
        isNot(same(firstToggleHabit)),
      );
      expect(
        container.read(updateHabitUseCaseProvider),
        isNot(same(firstUpdateHabit)),
      );
      expect(
        container.read(deleteHabitUseCaseProvider),
        isNot(same(firstDeleteHabit)),
      );
      expect(
        container.read(saveHabitsUseCaseProvider),
        isNot(same(firstSaveHabits)),
      );
      expect(
        container.read(domainNoteRepositoryProvider),
        isNot(same(firstNoteRepository)),
      );
      expect(
        container.read(getNotesUseCaseProvider),
        isNot(same(firstGetNotes)),
      );
      expect(
        container.read(createNoteUseCaseProvider),
        isNot(same(firstCreateNote)),
      );
      expect(
        container.read(updateNoteUseCaseProvider),
        isNot(same(firstUpdateNote)),
      );
      expect(
        container.read(archiveNoteUseCaseProvider),
        isNot(same(firstArchiveNote)),
      );
      expect(
        container.read(deleteNoteUseCaseProvider),
        isNot(same(firstDeleteNote)),
      );
      expect(
        container.read(identityRepositoryProvider),
        isNot(same(firstIdentityRepository)),
      );
      expect(
        container.read(firebaseSupabaseBridgeRepositoryProvider),
        isNot(same(firstFirebaseBridgeRepository)),
      );
    },
  );
}

final class _ScopeNotifier extends Notifier<AccountStorageScope> {
  @override
  AccountStorageScope build() => AccountStorageScope.authenticated('account-a');

  void setScope(AccountStorageScope value) => state = value;
}
