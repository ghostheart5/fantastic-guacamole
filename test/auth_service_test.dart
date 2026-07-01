import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chronospark/data/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late MockFirebaseAuth mockAuth;
  late AuthService sut;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    sut = AuthService(firebaseAuth: mockAuth);
  });

  group('authStateChanges', () {
    test('delegates to FirebaseAuth', () {
      final stream = Stream<User?>.value(null);
      when(() => mockAuth.authStateChanges()).thenAnswer((_) => stream);

      expect(sut.authStateChanges(), stream);
      verify(() => mockAuth.authStateChanges()).called(1);
    });
  });

  group('currentUser', () {
    test('returns null when no user signed in', () {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(sut.currentUser, isNull);
    });

    test('returns user when signed in', () {
      final user = MockUser();
      when(() => mockAuth.currentUser).thenReturn(user);
      expect(sut.currentUser, user);
    });
  });

  group('signIn', () {
    test('returns UserCredential on success', () async {
      final credential = MockUserCredential();
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          )).thenAnswer((_) async => credential);

      final result = await sut.signIn(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result, credential);
    });

    test('throws FirebaseAuthException on wrong password', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(
        FirebaseAuthException(code: 'wrong-password'),
      );

      expect(
        () => sut.signIn(email: 'test@example.com', password: 'wrong'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });

    test('throws FirebaseAuthException when user not found', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(
        FirebaseAuthException(code: 'user-not-found'),
      );

      expect(
        () => sut.signIn(email: 'noone@example.com', password: 'pass'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('signUp', () {
    test('returns UserCredential on success', () async {
      final credential = MockUserCredential();
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: 'new@example.com',
            password: 'password123',
          )).thenAnswer((_) async => credential);

      final result = await sut.signUp(
        email: 'new@example.com',
        password: 'password123',
      );

      expect(result, credential);
    });

    test('throws FirebaseAuthException when email already in use', () async {
      when(() => mockAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(
        FirebaseAuthException(code: 'email-already-in-use'),
      );

      expect(
        () => sut.signUp(email: 'taken@example.com', password: 'pass'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('sendPasswordReset', () {
    test('completes successfully', () async {
      when(() => mockAuth.sendPasswordResetEmail(email: 'test@example.com'))
          .thenAnswer((_) async {});

      await expectLater(
        sut.sendPasswordReset('test@example.com'),
        completes,
      );
    });

    test('throws FirebaseAuthException for unknown email', () async {
      when(() => mockAuth.sendPasswordResetEmail(
            email: any(named: 'email'),
          )).thenThrow(
        FirebaseAuthException(code: 'user-not-found'),
      );

      expect(
        () => sut.sendPasswordReset('ghost@example.com'),
        throwsA(isA<FirebaseAuthException>()),
      );
    });
  });

  group('signOut', () {
    test('delegates to FirebaseAuth', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await sut.signOut();

      verify(() => mockAuth.signOut()).called(1);
    });
  });

  group('deleteAccount', () {
    test('throws StateError when no user is signed in', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(
        () => sut.deleteAccount(),
        throwsA(isA<StateError>()),
      );
    });

    test('deletes user and signs out on success', () async {
      final user = MockUser();
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.delete()).thenAnswer((_) async {});
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await sut.deleteAccount();

      verify(() => user.delete()).called(1);
      verify(() => mockAuth.signOut()).called(1);
    });

    test('does not call signOut if delete throws', () async {
      final user = MockUser();
      when(() => mockAuth.currentUser).thenReturn(user);
      when(() => user.delete()).thenThrow(
        FirebaseAuthException(code: 'requires-recent-login'),
      );

      expect(
        () => sut.deleteAccount(),
        throwsA(isA<FirebaseAuthException>()),
      );
      verifyNever(() => mockAuth.signOut());
    });
  });
}
