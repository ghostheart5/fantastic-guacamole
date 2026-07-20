import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseClientService {
  const SupabaseClientService();

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode) {
      return null;
    }
    if (!Env.hasSupabaseCredentialsPresent) {
      return null;
    }
    if (!Env.isSupabaseConfigured) {
      return 'Supabase configuration is invalid. Auth will be unavailable.';
    }

    if (!Env.isSupabaseConfigured) {
      return null;
    }

    const int maxAttempts = 2;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await sb.Supabase.initialize(
          url: Env.supabaseUrl,
          publishableKey: Env.supabaseAnonKey,
        ).timeout(const Duration(seconds: 12));
        return null;
      } on TimeoutException {
        Logger.errorCategory(
          'Supabase Errors',
          'Supabase initialization timed out (attempt $attempt/$maxAttempts)',
        );
        if (attempt >= maxAttempts) {
          return 'Supabase initialization timed out. Auth will be unavailable.';
        }
      } on Exception catch (error) {
        Logger.errorCategory(
          'Supabase Errors',
          'Supabase initialization failed (attempt $attempt/$maxAttempts)',
          error,
        );
        if (attempt >= maxAttempts) {
          return 'Supabase initialization failed: $error';
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return 'Supabase initialization failed after retries.';
  }

  sb.SupabaseClient? get client {
    if (!Env.isSupabaseConfigured) {
      return null;
    }
    try {
      return sb.Supabase.instance.client;
    } on Object {
      return null;
    }
  }
}
