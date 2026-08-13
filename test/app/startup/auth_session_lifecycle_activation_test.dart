import 'dart:async';

import 'package:fantastic_guacamole/app/startup/app_bootstrap.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(String id) =>
    User(id: id, email: '$id@example.com', emailVerified: false);

void main() {
  group('AuthSessionLifecycleActivation', () {
    test(
      'initializes signed-out startup and subscribes exactly once',
      () async {
        int subscriptions = 0;
        final StreamController<User?> changes =
            StreamController<User?>.broadcast(onListen: () => subscriptions++);
        final List<String> calls = <String>[];
        final AuthSessionLifecycleActivation activation =
            AuthSessionLifecycleActivation(
              initialize: (User? user) async {
                calls.add('initialize:${user?.id ?? 'signed_out'}');
                return 1;
              },
              synchronize: (User? user) async {
                calls.add('synchronize:${user?.id ?? 'signed_out'}');
                return 1;
              },
              authStateChanges: changes.stream,
            );

        await activation.activate(null);
        await activation.activate(_user('ignored'));

        expect(calls, <String>['initialize:signed_out']);
        expect(subscriptions, 1);
        expect(activation.isActive, isTrue);

        await activation.dispose();
        await changes.close();
      },
    );

    test(
      'forwards authenticated transitions to the coordinator in order',
      () async {
        final StreamController<User?> changes = StreamController<User?>();
        final List<String> calls = <String>[];
        final AuthSessionLifecycleActivation activation =
            AuthSessionLifecycleActivation(
              initialize: (User? user) async {
                calls.add('initialize:${user?.id ?? 'signed_out'}');
                return 1;
              },
              synchronize: (User? user) async {
                calls.add('synchronize:${user?.id ?? 'signed_out'}');
                return 1;
              },
              authStateChanges: changes.stream,
            );

        await activation.activate(_user('A'));
        changes.add(_user('B'));
        await Future<void>.delayed(Duration.zero);

        expect(calls, <String>['initialize:A', 'synchronize:B']);

        await activation.dispose();
        await changes.close();
      },
    );

    test(
      'forwards same-user refresh without adding destructive logic',
      () async {
        final StreamController<User?> changes = StreamController<User?>();
        final List<String> calls = <String>[];
        final AuthSessionLifecycleActivation activation =
            AuthSessionLifecycleActivation(
              initialize: (User? user) async {
                calls.add('initialize:${user?.id ?? 'signed_out'}');
                return 1;
              },
              synchronize: (User? user) async {
                calls.add('synchronize:${user?.id ?? 'signed_out'}');
                return 1;
              },
              authStateChanges: changes.stream,
            );

        await activation.activate(_user('A'));
        changes.add(_user('A'));
        await Future<void>.delayed(Duration.zero);

        expect(calls, <String>['initialize:A', 'synchronize:A']);

        await activation.dispose();
        await changes.close();
      },
    );

    test('disposes its auth subscription cleanly', () async {
      int cancellations = 0;
      final StreamController<User?> changes = StreamController<User?>.broadcast(
        onCancel: () => cancellations++,
      );
      final AuthSessionLifecycleActivation activation =
          AuthSessionLifecycleActivation(
            initialize: (User? _) async => 1,
            synchronize: (User? _) async => 1,
            authStateChanges: changes.stream,
          );

      await activation.activate(null);
      await activation.dispose();

      expect(activation.isActive, isFalse);
      expect(cancellations, 1);

      await changes.close();
    });
  });
}
