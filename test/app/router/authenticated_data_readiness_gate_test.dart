import 'package:fantastic_guacamole/app/router/route_guards.dart';
import 'package:fantastic_guacamole/app/router/route_paths.dart';
import 'package:fantastic_guacamole/data/models/auth_models.dart';
import 'package:fantastic_guacamole/state/providers/auth_session_boundary_provider.dart';
import 'package:fantastic_guacamole/state/providers/authenticated_data_readiness_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const User userA = User(id: 'A', emailVerified: true);
  const User userB = User(id: 'B', emailVerified: true);

  AuthSessionBoundary boundary({
    String? userId,
    bool transitioning = false,
    bool storageReady = true,
    String? issue,
  }) {
    return AuthSessionBoundary(
      generation: 1,
      userId: userId,
      isTransitioning: transitioning,
      isStorageReady: storageReady,
      blockingIssue: issue,
    );
  }

  group('authenticated data readiness', () {
    test('distinguishes signed-out, transition, storage, blocked, mismatch, and ready', () {
      expect(
        resolveAuthenticatedDataReadiness(
          user: null,
          boundary: boundary(userId: null, transitioning: true, storageReady: false),
        ),
        AuthenticatedDataReadiness.signedOut,
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userA,
          boundary: boundary(userId: 'A', transitioning: true),
        ),
        AuthenticatedDataReadiness.transitioning,
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userA,
          boundary: boundary(userId: 'A', storageReady: false),
        ),
        AuthenticatedDataReadiness.storageNotReady,
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userA,
          boundary: boundary(userId: 'A', issue: 'migration blocked'),
        ),
        AuthenticatedDataReadiness.blocked,
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userB,
          boundary: boundary(userId: 'A'),
        ),
        AuthenticatedDataReadiness.userMismatch,
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userB,
          boundary: boundary(userId: ' B '),
        ),
        AuthenticatedDataReadiness.ready,
      );
    });

    test('keeps a matching same-user refresh ready', () {
      expect(
        resolveAuthenticatedDataReadiness(
          user: userA,
          boundary: boundary(userId: 'A'),
        ),
        AuthenticatedDataReadiness.ready,
      );
    });

    test('requires B boundary completion after A to B transition', () {
      expect(
        resolveAuthenticatedDataReadiness(
          user: userB,
          boundary: boundary(userId: 'A'),
        ),
        isNot(AuthenticatedDataReadiness.ready),
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userB,
          boundary: boundary(userId: 'B', transitioning: true),
        ),
        AuthenticatedDataReadiness.transitioning,
      );
      expect(
        resolveAuthenticatedDataReadiness(
          user: userB,
          boundary: boundary(userId: 'B'),
        ),
        AuthenticatedDataReadiness.ready,
      );
    });
  });

  group('authenticated route gate', () {
    const List<String> protectedRoutes = <String>[
      RoutePaths.home,
      RoutePaths.creator,
      RoutePaths.insights,
      RoutePaths.settings,
      RoutePaths.timeline,
      RoutePaths.profile,
      RoutePaths.si,
      RoutePaths.legacyTimeline,
      RoutePaths.legacyTasks,
      RoutePaths.legacyProfile,
      RoutePaths.legacySi,
    ];

    test('blocks representative, legacy, and direct authenticated routes until ready', () {
      for (final String route in protectedRoutes) {
        expect(requiresAuthenticatedDataReadiness(route), isTrue, reason: route);
        expect(
          resolveAuthenticatedDataRouteRedirect(
            isAuthenticated: true,
            readiness: AuthenticatedDataReadiness.transitioning,
            location: route,
          ),
          RoutePaths.bootstrap,
          reason: route,
        );
      }
    });

    test('blocks mismatched and storage-not-ready users, but allows matching ready users', () {
      for (final AuthenticatedDataReadiness readiness in <AuthenticatedDataReadiness>[
        AuthenticatedDataReadiness.storageNotReady,
        AuthenticatedDataReadiness.userMismatch,
      ]) {
        expect(
          resolveAuthenticatedDataRouteRedirect(
            isAuthenticated: true,
            readiness: readiness,
            location: RoutePaths.creator,
          ),
          RoutePaths.bootstrap,
        );
      }
      expect(
        resolveAuthenticatedDataRouteRedirect(
          isAuthenticated: true,
          readiness: AuthenticatedDataReadiness.ready,
          location: RoutePaths.creator,
        ),
        isNull,
      );
    });

    test('uses distinct blocking state and preserves signed-out login flow', () {
      expect(
        resolveAuthenticatedDataRouteRedirect(
          isAuthenticated: true,
          readiness: AuthenticatedDataReadiness.blocked,
          location: RoutePaths.settings,
        ),
        RoutePaths.sessionBlocked,
      );
      expect(
        resolveAuthenticatedDataRouteRedirect(
          isAuthenticated: false,
          readiness: AuthenticatedDataReadiness.signedOut,
          location: RoutePaths.login,
        ),
        isNull,
      );
    });
  });
}
