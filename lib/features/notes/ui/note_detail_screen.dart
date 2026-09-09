import 'package:fantastic_guacamole/state/providers/notes_provider.dart';
import 'package:fantastic_guacamole/features/notes/ui/note_actions.dart';
import 'package:fantastic_guacamole/ui/constants/app_assets.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/system/temporal_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Resolve the saved note from current account state, never from a stale route
/// payload. Opening a saved item must not stage or create another note.
class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final note = notes.isLoading || notes.hasError
        ? null
        : notes.asData?.value
              .where((item) => item.id == noteId && !item.isArchived)
              .firstOrNull;
    return AnimatedSystemBackground(
      backgroundAssetPath: AppAssets.bgCreatorIntent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TemporalScreenHeader(
                title: 'NOTE',
                eyebrow: 'Saved context',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              if (notes.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (notes.hasError) ...[
                const Text('This note could not be loaded.'),
                TextButton(
                  onPressed: () => ref.invalidate(notesProvider),
                  child: const Text('Retry'),
                ),
              ] else if (note == null)
                const Text('This note is no longer available in this account.')
              else
                TemporalGlassSurface(
                  accent: AppColors.memoryAmber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        note.body?.trim().isNotEmpty == true
                            ? note.body!
                            : 'No additional details.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      NoteActions(note: note),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
