import 'dart:io';

import 'package:fantastic_guacamole/l10n/creator_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Creator manual Save uses guarded confirmation and AI drafts keep review',
    () {
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
      expect(copy.reviewChanges, 'Review before saving');
      expect(copy.confirmSelected, 'Save selected changes');
      expect(copy.undo, 'Undo save');
      expect(
        copy.confirmBoundary,
        startsWith('Check the selected change below. Confirm to save it.'),
      );
      expect(
        screen,
        contains('submitLabel: guidedFirstTask || plannerDraft != null'),
      );
      expect(screen, contains('staged.canConfirm'));
      expect(screen, contains('staged.preview?.operations.length == 1'));
      expect(screen, matches(RegExp(r'hasBoundEvidence\s*!=\s*true')));
      expect(screen, contains('notifier.confirm()'));
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
    },
  );
}
