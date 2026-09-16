import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceConsentResetButton extends ConsumerWidget {
  const VoiceConsentResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spanish = ChronoSparkLocalizations.of(context).isSpanish;
    return TextButton.icon(
      icon: const Icon(Icons.mic_off_outlined),
      label: Text(
        spanish ? 'Restablecer consentimiento de voz' : 'Reset voice consent',
      ),
      onPressed: () async {
        final store = ref.read(voiceInputConsentStoreProvider);
        final controller = ref.read(voiceControllerProvider.notifier);
        try {
          await Future.wait<void>(<Future<void>>[
            store.revoke(),
            controller.stopListening(),
          ]);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                spanish
                    ? 'Consentimiento restablecido. El próximo dictado pedirá tu aprobación.'
                    : 'Voice consent reset. Your next dictation will ask for approval.',
              ),
            ),
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                spanish
                    ? 'No se pudo guardar el cambio. Inténtalo de nuevo.'
                    : 'Could not save the change. Please try again.',
              ),
            ),
          );
        }
      },
    );
  }
}
