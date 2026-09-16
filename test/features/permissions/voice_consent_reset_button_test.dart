import 'package:fantastic_guacamole/core/storage/account_storage_scope.dart';
import 'package:fantastic_guacamole/features/permissions/voice_consent_reset_button.dart';
import 'package:fantastic_guacamole/state/controllers/voice_controller.dart';
import 'package:fantastic_guacamole/state/providers/voice_input_consent_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Settings reset removes consent, stops capture and invalidates pending approval',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = VoiceInputConsentStore(
        AccountStorageScope.authenticated('review-reset'),
      );
      await store.remember(store.revision);
      expect(await store.isApproved(), isTrue);
      final oldRevision = store.revision;
      final voice = _Voice();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceInputConsentStoreProvider.overrideWithValue(store),
            voiceControllerProvider.overrideWith(() => voice),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VoiceConsentResetButton()),
          ),
        ),
      );
      await tester.tap(find.text('Reset voice consent'));
      await tester.pumpAndSettle();
      expect(await store.isApproved(), isFalse);
      expect(store.isCurrent(oldRevision), isFalse);
      expect(voice.stops, 1);
      await store.remember(oldRevision);
      expect(await store.isApproved(), isFalse);
      expect(
        find.text(
          'Voice consent reset. Your next dictation will ask for approval.',
        ),
        findsOneWidget,
      );
    },
  );
}

class _Voice extends VoiceController {
  int stops = 0;
  @override
  VoiceState build() => const VoiceState();
  @override
  Future<void> stopListening() async {
    stops++;
  }
}
