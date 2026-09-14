import 'dart:io';

import 'package:fantastic_guacamole/l10n/creator_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Creator production UI has no direct unconfirmed mutation path', () {
    final String screen = File(
      'lib/features/creator/ui/creator_screen.dart',
    ).readAsStringSync();
    final String handshake = File(
      'lib/state/providers/creator_handshake_provider.dart',
    ).readAsStringSync();
    final String contract = File(
      'lib/domain/entities/creator_handshake.dart',
    ).readAsStringSync();

    // Visible copy is localized; the screen must still expose each safeguard.
    const copy = CreatorCopy(false);
    expect(copy.reviewChanges, 'REVIEW CHANGES');
    expect(copy.confirmSelected, 'CONFIRM SELECTED');
    expect(copy.undo, 'Undo creation');
    expect(
      copy.confirmBoundary,
      startsWith('Nothing is saved until you confirm'),
    );
    expect(screen, contains('submitLabel: copy.reviewChanges'));
    expect(screen, contains('copy.confirmSelected'));
    expect(screen, contains('Text(copy.undo)'));
    expect(screen, contains('copy.confirmBoundary'));
    expect(screen, isNot(contains('creatorActionsProvider).createTask')));
    expect(screen, isNot(contains('taskActionsProvider).createTask')));
    expect(screen, isNot(contains('createTaskUseCaseProvider')));

    expect(handshake, contains('CreatorConfirmationToken'));
    expect(contract, contains('displayedDiffDigest'));
    expect(contract, contains('selectedOperationIds'));
    expect(contract, contains('baseDomainRevision'));
    expect(handshake, contains('confirmationLifetime'));
    expect(handshake, contains('CreatorHandshakePhase.idempotent'));
    expect(handshake, contains('Future<CreatorHandshakeState> undo()'));
    expect(handshake, isNot(contains('AppAnalytics')));
    expect(handshake, isNot(contains('timelineActionsProvider')));
    expect(handshake, isNot(contains('logsActionsProvider')));
    expect(handshake, isNot(contains('profileProvider')));
    expect(handshake, isNot(contains('siStateProvider')));
  });
}
