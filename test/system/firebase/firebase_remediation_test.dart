import 'dart:convert';

import 'package:fantastic_guacamole/core/debug/app_analytics.dart';
import 'package:fantastic_guacamole/data/services/remote_config_service.dart';
import 'package:fantastic_guacamole/system/firebase/firebase_messaging_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    FirebaseMessagingBootstrap.configureTokenRefreshHandler(null);
    AppAnalytics.userAttributionOverride = null;
    AppAnalytics.screenViewOverride = null;
  });

  test('FCM notification opens are allowlisted and idempotent', () {
    final List<String> payloads = <String>[];
    final FirebaseNotificationOpenAdapter adapter =
        FirebaseNotificationOpenAdapter(onOpen: payloads.add);

    expect(
      adapter.handle(
        data: <String, dynamic>{'destination': 'timeline'},
        messageId: 'message-1',
      ),
      isTrue,
    );
    expect(
      adapter.handle(
        data: <String, dynamic>{'destination': 'timeline'},
        messageId: 'message-1',
      ),
      isFalse,
    );
    expect(
      adapter.handle(
        data: <String, dynamic>{'destination': 'https://untrusted.example'},
        messageId: 'message-2',
      ),
      isFalse,
    );
    expect(payloads, hasLength(1));
    expect(jsonDecode(payloads.single), <String, dynamic>{
      'destination': 'timeline',
    });
  });

  test('FCM token refresh invokes the persistence and sync callback', () async {
    String? handledToken;
    FirebaseMessagingBootstrap.configureTokenRefreshHandler((
      String token,
    ) async {
      handledToken = token;
    });

    await FirebaseMessagingBootstrap.handleTokenRefreshForTesting(
      ' refreshed-token ',
    );

    expect(handledToken, 'refreshed-token');
    expect(FirebaseMessagingBootstrap.latestToken, 'refreshed-token');
  });

  test(
    'analytics user attribution clears and screen tracking is normalized',
    () async {
      final List<String?> userIds = <String?>[];
      final List<String> screens = <String>[];
      AppAnalytics.userAttributionOverride = (String? userId) async {
        userIds.add(userId);
      };
      AppAnalytics.screenViewOverride = (String screenName) async {
        screens.add(screenName);
      };

      await AppAnalytics.identifySupabaseUser(' supabase-user ');
      await AppAnalytics.identifySupabaseUser(' ');
      await AppAnalytics.trackScreen(' /timeline ');

      expect(userIds, <String?>['supabase-user', null]);
      expect(screens, <String>['/timeline']);
    },
  );

  test(
    'Remote Config refresh retains initial defaults after a fetch failure',
    () async {
      final RemoteConfigService service = RemoteConfigService(
        initialValues: <String, Object?>{'flag_enabled': true},
        refreshOverride: () async => throw StateError('offline'),
      );

      await service.refresh();

      expect(service.getBool('flag_enabled'), isTrue);
    },
  );
}
