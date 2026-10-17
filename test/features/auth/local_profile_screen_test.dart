import 'package:fantastic_guacamole/data/services/local_profile_auth_service.dart';
import 'package:fantastic_guacamole/data/storage/secure_store.dart';
import 'package:fantastic_guacamole/features/auth/ui/local_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  testWidgets(
    'failed profile opening is localized and preserves the stored profile',
    (tester) async {
      final backend = _FailingWritesBackend();
      final service = LocalProfileAuthService(
        store: SecureStore(backend: backend),
        onProfileDeleted: (_) async {},
        onBeforeClosed: (_) async {},
      );
      await service.createProfile(displayName: 'Saved synthetic name');
      await service.signOut();
      backend.failWrites = true;
      await tester.pumpWidget(_localizedHost(service, const Locale('es')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('local-profile-continue')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No se pudo abrir tu perfil local. Inténtalo de nuevo; tu perfil guardado no se ha reemplazado.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Your local profile could not be opened'),
        findsNothing,
      );
      expect(service.hasStoredProfile, isTrue);
      expect(service.currentUser, isNull);
      await tester.pumpWidget(_localizedHost(service, const Locale('en')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your local profile could not be opened. Retry; your saved profile has not been replaced.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await service.dispose();
    },
  );

  testWidgets('failed deletion retry explains the closed profile in Spanish', (
    tester,
  ) async {
    final service = LocalProfileAuthService(
      store: SecureStore(backend: InMemorySecureStoreBackend()),
      onProfileDeleted: (_) async {
        throw StateError('synthetic unavailable store');
      },
      onBeforeClosed: (_) async {},
    );
    await service.createProfile();
    await expectLater(
      service.deleteCurrentAccount(password: ''),
      throwsStateError,
    );
    await tester.pumpWidget(_localizedHost(service, const Locale('es')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('local-profile-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La eliminación no se completó. Tu perfil permanece cerrado. Inténtalo de nuevo para terminar de eliminar sus datos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar eliminación'), findsOneWidget);
    expect(find.textContaining('Deletion is incomplete'), findsNothing);
    expect(service.hasPendingDeletion, isTrue);
    expect(service.currentUser, isNull);
    await tester.pumpWidget(const SizedBox());
    await service.dispose();
  });

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

Widget _localizedHost(LocalProfileAuthService service, Locale locale) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LocalProfileScreen(service: service),
    );

class _FailingWritesBackend extends InMemorySecureStoreBackend {
  bool failWrites = false;

  @override
  Future<void> write({required String key, required String value}) {
    if (failWrites) throw StateError('synthetic write failure');
    return super.write(key: key, value: value);
  }
}
