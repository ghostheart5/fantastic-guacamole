import 'package:fantastic_guacamole/domain/entities/creator_handshake.dart';
import 'package:fantastic_guacamole/l10n/journey_copy.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/models/creator_form_data.dart';
import 'package:fantastic_guacamole/state/providers/creator_navigation_intent_provider.dart';
import 'package:fantastic_guacamole/tutorial/adaptive_guidance.dart';
import 'package:fantastic_guacamole/ui/navigation/app_view_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An explicit item choice opens the normal form. It must never silently
/// become the tutorial's scheduled first-task exercise, even on a fresh account.
Future<void> openCreatorForItem(
  BuildContext context,
  WidgetRef ref,
  CreatorFormKind kind,
) async {
  final generation = ref.read(authSessionBoundaryProvider).generation;
  final namespace = ref.read(accountStorageScopeProvider).v2Namespace;
  bool current() {
    if (!context.mounted) return false;
    final boundary = ref.read(authSessionBoundaryProvider);
    final scope = ref.read(accountStorageScopeProvider);
    return boundary.generation == generation &&
        scope.v2Namespace == namespace &&
        scope.isWritable &&
        boundary.isStorageReady &&
        !boundary.isTransitioning &&
        boundary.blockingIssue == null;
  }

  if (!current()) return;
  try {
    final guidance = await ref.read(adaptiveGuidanceProvider.future);
    if (!current()) return;
    if (guidance.activeCoreLesson case final lesson?) {
      await ref.read(adaptiveGuidanceProvider.notifier).later(lesson);
    }
    if (!context.mounted || !current()) return;
    ref.read(creatorHandshakeProvider.notifier).clearResult();
    if (ref.read(creatorHandshakeProvider).phase !=
        CreatorHandshakePhase.idle) {
      throw StateError('An existing save or undo is still in progress.');
    }
    ref.read(creatorDraftPreviewProvider.notifier).clear();
    ref.read(creatorNavigationIntentProvider.notifier).open(kind);
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    goToAppView(context, ref, AppView.creator);
  } catch (_) {
    if (!context.mounted || !current()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          journeyText(
            context,
            'Could not open the form. Please try again.',
            'No se pudo abrir el formulario. Inténtalo de nuevo.',
          ),
        ),
      ),
    );
  }
}
