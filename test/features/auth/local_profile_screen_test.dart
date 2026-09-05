import 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/auth/ui/local_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'local entry creates a device profile without credential or tester forms',
    (tester) async {
      final service = LocalProfileAuthService(
        store: SecureStore(backend: InMemorySecureStoreBackend()),
        onProfileDeleted: (_) async {},
        onBeforeClosed: (_) async {},
      );
      await service.initialize();
      await tester.pumpWidget(
        MaterialApp(home: LocalProfileScreen(service: service)),
      );
      expect(find.text('Create a local profile'), findsOneWidget);
      expect(find.text('Create profile'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Google'), findsNothing);
      expect(find.textContaining('Tester'), findsNothing);
      await tester.enterText(find.byType(TextField), 'My device');
      await tester.tap(find.byKey(const Key('local-profile-continue')));
      await tester.pumpAndSettle();
      expect(service.currentUser?.isLocalProfile, isTrue);
      expect(service.currentUser?.email, isNull);
      await tester.pumpWidget(const SizedBox());
      await service.dispose();
    },
  );

  testWidgets('an interrupted deletion offers retry, never a new profile', (
    tester,
  ) async {
    int attempts = 0;
    final service = LocalProfileAuthService(
      store: SecureStore(backend: InMemorySecureStoreBackend()),
      onProfileDeleted: (_) async {
        if (++attempts == 1) throw StateError('failed');
      },
      onBeforeClosed: (_) async {},
    );
    await service.createProfile();
    await expectLater(
      service.deleteCurrentAccount(password: ''),
      throwsStateError,
    );
    await tester.pumpWidget(
      MaterialApp(home: LocalProfileScreen(service: service)),
    );
    expect(find.text('Retry deletion'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('local-profile-continue')));
    await tester.pumpAndSettle();
    expect(service.hasStoredProfile, isFalse);
    expect(find.text('Create profile'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await service.dispose();
  });
}
