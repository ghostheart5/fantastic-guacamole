import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final Directory root = Directory.current;

  String read(String path) =>
      File.fromUri(root.uri.resolve(path)).readAsStringSync();

  test('AI reporting is authenticated, bounded, and configured', () {
    final String service = read(
      'lib/data/services/ai/ai_content_report_service.dart',
    );
    final String function = read('supabase/functions/ai-report/index.ts');
    final String config = read('supabase/config.toml');
    final String migration = read(
      'supabase/migrations/20260817214812_ai_content_reports.sql',
    );

    expect(service, contains("substring(0, 4000)"));
    expect(service, contains(r"'Authorization': 'Bearer $accessToken'"));
    expect(function, contains('/auth/v1/user'));
    expect(function, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(function, contains('withinRateLimit'));
    expect(config, contains('[functions.ai-report]'));
    expect(config, contains('verify_jwt = true'));
    expect(migration, contains('enable row level security'));
    expect(
      migration,
      contains('revoke all on table public.ai_content_reports'),
    );
  });

  test(
    'Phase 2 cloud data boundaries fail closed in the forward migration',
    () {
      final String migration = read(
        'supabase/migrations/20260830050000_phase2_data_security_hardening.sql',
      );
      final String casTests = read(
        'supabase/tests/cloud_backup_snapshots_rls.test.sql',
      );
      final String securityTests = read(
        'supabase/tests/phase2_data_security.test.sql',
      );

      expect(
        RegExp('account_deletion_in_progress').allMatches(migration).length,
        greaterThanOrEqualTo(4),
      );
      expect(
        migration,
        contains(
          'grant insert on table public.ai_content_reports to service_role',
        ),
      );
      expect(migration, contains('grant usage on sequence'));
      expect(migration, contains('file_size_limit = 5242880'));
      expect(
        migration,
        contains("allowed_mime_types = array['application/json']"),
      );
      expect(migration, contains("'/backup/full_backup.json'"));
      expect(migration, contains("'/backup/tasks_backup.json'"));
      expect(migration, isNot(contains("split_part(name, '/', 1)")));
      expect(casTests, contains('a deletion tombstone blocks CAS inserts'));
      expect(securityTests, contains('every legacy sync policy is restricted'));
    },
  );

  test('startup does not request push permission; explicit flow does', () {
    final String source = read(
      'lib/system/firebase/firebase_messaging_bootstrap.dart',
    );
    final int initializer = source.indexOf('Future<String?> _initializeOnce()');
    final int explicit = source.indexOf('requestPermissionAndToken');
    expect(initializer, greaterThanOrEqualTo(0));
    expect(explicit, greaterThan(initializer));
    final int initializerEnd = source.indexOf('\n  }', initializer);
    final String initializerBody = source.substring(
      initializer,
      initializerEnd,
    );
    expect(initializerBody, isNot(contains('requestPermission')));
    expect(source.substring(explicit), contains('requestPermission('));
  });

  test('published policy copies identify one current data contract', () {
    final String policy = read('web/privacy/index.html');
    final String bundled = read('assets/legal/privacy_policy.txt');
    expect(
      policy,
      contains(
        'Account and security services may use Supabase for authentication',
      ),
    );
    expect(
      policy,
      contains(
        'current release candidate does not send Planner content to an external generative-AI provider',
      ),
    );
    expect(policy, contains('Anthropic is the disclosed provider'));
    expect(
      policy,
      contains('Firebase Analytics and Crashlytics are release-contained off'),
    );
    expect(
      bundled,
      contains(
        'This policy describes the data ChronoSpark may process and the stricter feature containment',
      ),
    );
    expect(bundled, contains('External AI\n\nDisabled.'));
    expect(bundled, contains('ghostheart131517@gmail.com'));
    expect(
      read('lib/config/env.dart'),
      contains("supportEmail = 'ghostheart131517@gmail.com'"),
    );
    expect(
      read('lib/features/settings/ui/settings_screen.dart'),
      isNot(contains('support@chronospark.app')),
    );
    expect(
      bundled.toLowerCase(),
      isNot(
        contains(
          'fo'
          'cus session',
        ),
      ),
    );
    expect(bundled.toLowerCase(), isNot(contains('session data')));
  });

  test('all checked-in support and deletion surfaces use one mailbox', () {
    const String canonical = 'ghostheart131517@gmail.com';
    const String retired = 'support@chronospark.app';
    expect(read('lib/config/env.dart'), contains(canonical));
    expect(
      read('lib/features/settings/ui/settings_screen.dart'),
      contains('Env.supportEmail'),
    );
    for (final String path in <String>[
      'privacy.html',
      'web/privacy/index.html',
      'web/terms/index.html',
      'terms/index.html',
      'web/support/index.html',
      'web/delete-account/index.html',
      'assets/legal/privacy_policy.txt',
      'assets/legal/terms_of_service.txt',
      'assets/legal/terms_of_service.html',
      'assets/legal/support.txt',
      'assets/legal/support.html',
      'assets/legal/delete_account.html',
      'assets/legal/delete_account.txt',
      'docs/delete-account.html',
      'contact.html',
      'support.html',
      'testers.html',
    ]) {
      final String source = read(path);
      expect(source, contains(canonical), reason: path);
      expect(source, isNot(contains(retired)), reason: path);
    }
  });

  test('published legal copies lock the adult-only target audience', () {
    for (final String path in <String>[
      'privacy.html',
      'web/privacy/index.html',
      'assets/legal/privacy_policy.html',
      'assets/legal/privacy_policy.txt',
    ]) {
      expect(
        read(path),
        contains('intended for adults ages 18 and over'),
        reason: path,
      );
    }

    for (final String path in <String>[
      'terms/index.html',
      'web/terms/index.html',
      'assets/legal/terms_of_service.html',
      'assets/legal/terms_of_service.txt',
    ]) {
      expect(
        read(path),
        contains('must be at least 18 years old'),
        reason: path,
      );
    }
  });

  test('OAuth fallback uses the app callback scheme', () {
    final String endpoints = read('lib/config/src/service_endpoints.dart');
    expect(endpoints, contains("defaultValue: 'chronospark://auth-callback'"));
  });

  test('local dotenv is compile-time input and never a Flutter asset', () {
    final YamlMap pubspec = loadYaml(read('pubspec.yaml')) as YamlMap;
    final YamlMap flutter = pubspec['flutter'] as YamlMap;
    final YamlList assets = flutter['assets'] as YamlList;
    final RegExp dotenvAsset = RegExp(r'(^|[\\/])\.env(?:\..+)?$');

    final Iterable<String> assetPaths = assets.map((dynamic asset) {
      if (asset is String) {
        return asset;
      }
      if (asset is YamlMap) {
        return asset['path']?.toString() ?? '';
      }
      return '';
    });
    expect(assetPaths.where(dotenvAsset.hasMatch), isEmpty);

    expect(
      read('lib/app/startup/app_bootstrap.dart'),
      isNot(contains('flutter_dotenv')),
    );
    expect(
      read('lib/app/startup/startup_error_hooks.dart'),
      isNot(contains('dotenv.load')),
    );
    expect(
      read('.vscode/launch.json'),
      contains('--dart-define-from-file=.env'),
    );
    expect(
      read('scripts/flutter_windows_run_local_nuget.ps1'),
      contains('--dart-define-from-file=.env'),
    );
  });

  test('Flutter bundles only explicit, existing application assets', () {
    final YamlMap pubspec = loadYaml(read('pubspec.yaml')) as YamlMap;
    final YamlMap flutter = pubspec['flutter'] as YamlMap;
    final Set<String> declared = (flutter['assets'] as YamlList)
        .map((dynamic value) => value.toString())
        .toSet();

    expect(
      declared.where((String path) => path.endsWith('/')),
      isEmpty,
      reason: 'Directory declarations silently bundle unused files.',
    );
    for (final String path in declared) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }

    final RegExp appAssetLiteral = RegExp(r"'((?:assets/)[^']+)'");
    final Set<String> appAssets = appAssetLiteral
        .allMatches(read('lib/ui/constants/app_assets.dart'))
        .map((RegExpMatch match) => match.group(1)!)
        .toSet();
    expect(declared, containsAll(appAssets));
  });

  test('public pages do not claim unapproved AI, billing, or platforms', () {
    final String landing = read('index.html');
    final String download = read('download.html');
    final String webShell = read('web/index.html');
    final String manifest = read('web/manifest.json');

    expect(landing, isNot(contains('<span class="tag">Premium</span>')));
    expect(landing, isNot(contains('<span class="tag">Ultimate</span>')));
    expect(download, contains('No public download is currently claimed'));
    expect(webShell, isNot(contains('optional AI assistance')));
    expect(manifest, isNot(contains('optional AI assistance')));
    expect(
      webShell,
      isNot(contains('Android, iOS, Windows, macOS, Linux, Web')),
    );
  });
}
