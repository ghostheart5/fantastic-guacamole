import 'dart:convert';
import 'dart:io';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/ui/constants/app_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production URL policy', () {
    test('public URLs share the deployed GitHub Pages origin', () {
      expect(
        <String>{
          AppUrls.website,
          AppUrls.privacy,
          AppUrls.terms,
          AppUrls.support,
          AppUrls.deleteAccount,
        }.every(
          (String value) =>
              value == Env.publicWebsiteUrl ||
              value.startsWith('${Env.publicWebsiteUrl}/'),
        ),
        isTrue,
      );
    });

    test('custom callback is supported outside production readiness only', () {
      expect(
        Env.resolveIsAllowedAuthRedirect(Env.customSchemeAuthCallbackUrl),
        isTrue,
      );
      expect(
        Env.resolveIsAllowedAuthRedirect(
          Env.customSchemeAuthCallbackUrl,
          requireHttpsAppLink: true,
        ),
        isFalse,
      );
      expect(
        Env.resolveIsAllowedAuthRedirect(
          Env.productionAuthCallbackUrl,
          requireHttpsAppLink: true,
        ),
        isTrue,
      );
    });

    test('callback policy rejects unregistered or payload-bearing URLs', () {
      for (final String value in <String>[
        'http://chronospark.app/app/auth/callback',
        'https://www.chronospark.app/app/auth/callback',
        'https://chronospark.app/app/auth/callback/extra',
        'https://chronospark.app/app/auth/callback?next=other',
        'https://ghostheart5.github.io/fantastic-guacamole/app/auth/callback',
        'other-app://auth-callback',
      ]) {
        expect(
          Env.resolveIsAllowedAuthRedirect(value, requireHttpsAppLink: true),
          isFalse,
          reason: value,
        );
      }
    });

    test('authenticated endpoints must be exact Supabase functions', () {
      const String supabaseUrl = 'https://example.supabase.co';
      expect(
        Env.resolveIsTrustedEdgeFunctionEndpoint(
          endpoint: '$supabaseUrl/functions/v1/monetization-verify',
          supabaseUrl: supabaseUrl,
          functionName: 'monetization-verify',
        ),
        isTrue,
      );

      for (final String endpoint in <String>[
        'http://example.supabase.co/functions/v1/monetization-verify',
        'https://attacker.example/functions/v1/monetization-verify',
        '$supabaseUrl/functions/v1/other',
        '$supabaseUrl/functions/v1/monetization-verify?redirect=other',
        'https://user@example.supabase.co/functions/v1/monetization-verify',
      ]) {
        expect(
          Env.resolveIsTrustedEdgeFunctionEndpoint(
            endpoint: endpoint,
            supabaseUrl: supabaseUrl,
            functionName: 'monetization-verify',
          ),
          isFalse,
          reason: endpoint,
        );
      }
    });

    test('invalid Supabase configuration has no receipt fallback host', () {
      expect(Env.resolveReceiptVerifyEndpoint('', supabaseUrl: ''), isEmpty);
      expect(
        Env.resolveReceiptVerifyEndpoint(
          '',
          supabaseUrl: 'https://example.supabase.co',
        ),
        'https://example.supabase.co/functions/v1/monetization-verify',
      );
    });

    test('Android SHA-256 requires exactly 32 colon-separated bytes', () {
      final String valid = List<String>.filled(32, 'AB').join(':');
      expect(Env.resolveIsValidAndroidSha256CertificateDigest(valid), isTrue);
      expect(
        Env.resolveIsValidAndroidSha256CertificateDigest('AB:CD'),
        isFalse,
      );
      expect(
        Env.resolveIsValidAndroidSha256CertificateDigest(
          List<String>.filled(32, 'ZZ').join(':'),
        ),
        isFalse,
      );
    });
  });

  group('checked-in public infrastructure', () {
    test('Android claims only the canonical custom App Link host', () {
      final String manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:host="chronospark.app"'));
      expect(manifest, isNot(contains('android:host="www.chronospark.app"')));
      expect(manifest, contains('android:path="/app"'));
      expect(manifest, contains('android:pathPrefix="/app/"'));
      expect(manifest, contains('android:host="auth-callback"'));
    });

    test('Digital Asset Links package and fingerprints are well formed', () {
      final Object? decoded = jsonDecode(
        File('web/.well-known/assetlinks.json').readAsStringSync(),
      );
      final List<Object?> statements = decoded! as List<Object?>;
      final Map<String, Object?> statement =
          statements.single! as Map<String, Object?>;
      final Map<String, Object?> target =
          statement['target']! as Map<String, Object?>;
      final List<Object?> fingerprints =
          target['sha256_cert_fingerprints']! as List<Object?>;

      expect(target['package_name'], 'com.ghostheart5.chronospark');
      expect(fingerprints, isNotEmpty);
      for (final Object? fingerprint in fingerprints) {
        expect(
          Env.resolveIsValidAndroidSha256CertificateDigest(
            fingerprint! as String,
          ),
          isTrue,
        );
      }
    });

    test('canonical legal routes are deployable from web sources', () {
      final Map<String, List<String>> contracts = <String, List<String>>{
        'web/privacy/index.html': <String>[
          '/fantastic-guacamole/privacy/',
          'Supabase',
          'Firebase',
        ],
        'web/terms/index.html': <String>[
          '/fantastic-guacamole/terms/',
          'Google Play',
          'does not automatically cancel',
        ],
        'web/support/index.html': <String>[
          '/fantastic-guacamole/support/',
          '../delete-account/',
        ],
        'web/delete-account/index.html': <String>[
          '/fantastic-guacamole/delete-account/',
          'Request deletion without the app',
          'does not cancel an active Google Play subscription',
        ],
      };

      for (final MapEntry<String, List<String>> entry in contracts.entries) {
        final File file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: entry.key);
        final String source = file.readAsStringSync();
        final String normalizedSource = source.replaceAll(RegExp(r'\s+'), ' ');
        for (final String requiredText in entry.value) {
          expect(normalizedSource, contains(requiredText), reason: entry.key);
        }
      }
    });

    test('Pages workflow publishes canonical sources and deletion route', () {
      final String workflow = File(
        '.github/workflows/main.yml',
      ).readAsStringSync();

      expect(
        workflow,
        contains(
          'cp web/delete-account/index.html build/web/delete-account/index.html',
        ),
      );
      expect(
        workflow,
        contains('cp web/privacy/index.html build/web/privacy/index.html'),
      );
      expect(
        workflow,
        contains(
          'cp web/.well-known/assetlinks.json '
          'build/web/.well-known/assetlinks.json',
        ),
      );
      expect(
        workflow,
        isNot(
          contains(
            'cp assets/legal/delete_account.html build/web/delete-account/index.html',
          ),
        ),
      );
    });

    test('production auth callback has a no-leak web fallback', () {
      final String callback = File(
        'web/app/auth/callback/index.html',
      ).readAsStringSync();

      expect(
        callback,
        contains('<meta name="referrer" content="no-referrer">'),
      );
      expect(
        callback,
        contains('<meta name="robots" content="noindex,nofollow">'),
      );
      expect(callback, contains('Return to ChronoSpark'));
      expect(
        callback,
        contains('never displays or sends authentication parameters'),
      );
      expect(callback, isNot(contains('document.write')));
    });

    test(
      'Android release uses the verified HTTPS callback without iOS gates',
      () {
        final String workflow = File(
          '.github/workflows/android-release.yml',
        ).readAsStringSync();
        final String guardedScript = File(
          'scripts/build_android_aab_prod_guarded.ps1',
        ).readAsStringSync();

        expect(
          workflow,
          contains(
            '--dart-define=CHRONOSPARK_OAUTH_REDIRECT_URL='
            'https://chronospark.app/app/auth/callback',
          ),
        );
        expect(
          workflow,
          contains(
            '--dart-define=CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL='
            'https://chronospark.app/app/auth/callback',
          ),
        );
        expect(
          workflow,
          contains(
            '--dart-define=CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL='
            'https://chronospark.app/app/auth/callback',
          ),
        );
        expect(
          guardedScript,
          contains(
            "CHRONOSPARK_PASSWORD_RECOVERY_REDIRECT_URL = "
            "'https://chronospark.app/app/auth/callback'",
          ),
        );
        expect(
          guardedScript,
          contains(
            "CHRONOSPARK_GITHUB_OAUTH_REDIRECT_URL = "
            "'https://chronospark.app/app/auth/callback'",
          ),
        );
        expect(workflow, isNot(contains('CHRONOSPARK_IOS_TEAM_ID')));
      },
    );

    test('release is blocked by database and Play App Links gates', () {
      final String releaseWorkflow = File(
        '.github/workflows/android-release.yml',
      ).readAsStringSync();
      final String databaseWorkflow = File(
        '.github/workflows/supabase-database.yml',
      ).readAsStringSync();

      expect(
        releaseWorkflow,
        contains('needs: [database-gate, public-infrastructure-gate]'),
      );
      expect(
        releaseWorkflow,
        contains('uses: ./.github/workflows/supabase-database.yml'),
      );
      expect(
        releaseWorkflow,
        contains('Verify Play signing certificate is published for App Links'),
      );
      expect(
        releaseWorkflow,
        contains("Path('web/.well-known/assetlinks.json')"),
      );
      expect(releaseWorkflow, contains('Play Console > App integrity'));
      expect(
        releaseWorkflow,
        contains('https://chronospark.app/.well-known/assetlinks.json'),
      );
      expect(
        releaseWorkflow,
        contains('https://chronospark.app/app/auth/callback'),
      );

      expect(databaseWorkflow, contains('version: 2.113.0'));
      expect(
        databaseWorkflow,
        contains(
          'deno lint supabase/functions supabase/drift/verify_manifest.ts',
        ),
      );
      expect(
        databaseWorkflow,
        contains('deno check supabase/functions/*/index.ts'),
      );
      expect(databaseWorkflow, contains('run: supabase db start'));
      expect(
        databaseWorkflow,
        contains('run: supabase test db --local supabase/tests'),
      );
      expect(
        databaseWorkflow,
        contains(
          'run: supabase db lint --local --schema public --fail-on error',
        ),
      );
    });
  });
}
