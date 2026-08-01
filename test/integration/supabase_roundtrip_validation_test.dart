import 'package:fantastic_guacamole/devtools/supabase_roundtrip_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bool runLive = bool.fromEnvironment(
    'CHRONOSPARK_RUN_SUPABASE_LIVE_VALIDATION',
    defaultValue: false,
  );
  const String supabaseUrl = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_URL',
    defaultValue: '',
  );
  const String supabaseAnonKey = String.fromEnvironment(
    'CHRONOSPARK_SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  const String email = String.fromEnvironment(
    'CHRONOSPARK_VALIDATION_EMAIL',
    defaultValue: '',
  );
  const String password = String.fromEnvironment(
    'CHRONOSPARK_VALIDATION_PASSWORD',
    defaultValue: '',
  );

  final bool hasConfig =
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      email.isNotEmpty &&
      password.isNotEmpty;

  test(
    'supabase roundtrip validation (opt-in live test)',
    () async {
      if (!runLive || !hasConfig) {
        return;
      }

      try {
        await sb.Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
      } on Object {
        // Supabase may already be initialized in some test runners.
      }

      final sb.SupabaseClient client = sb.Supabase.instance.client;
      await client.auth.signInWithPassword(email: email, password: password);

      final SupabaseRoundtripValidationReport report =
          await SupabaseRoundtripValidator(client: client).run();

      final List<ValidationItem> hardFailures = report.items
          .where((ValidationItem item) {
            if (item.state != ValidationState.fail) {
              return false;
            }
            // Non-Supabase core entities are intentionally local today.
            return item.category != 'CORE PRODUCTIVITY ENTITIES';
          })
          .toList(growable: false);

      expect(hardFailures, isEmpty);
    },
    skip: !runLive || !hasConfig,
  );
}
