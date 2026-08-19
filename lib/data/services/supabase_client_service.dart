import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseClientService {
  const SupabaseClientService();

  static Future<String?>? _initialization;

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode || !Env.isSupabaseConfigured) {
      return null;
    }
    final Future<String?>? inFlight = _initialization;
    if (inFlight != null) return inFlight;
    final Future<String?> initialization = _initializeOnce();
    _initialization = initialization;
    return initialization;
  }

  Future<String?> _initializeOnce() async {
    try {
      await sb.Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      ).timeout(const Duration(seconds: 12));
      return null;
    } on TimeoutException {
      Logger.errorCategory(
        'Supabase Errors',
        'Supabase initialization timed out',
      );
      return 'Supabase initialization timed out. Auth will be unavailable.';
    } on Object catch (error) {
      Logger.errorCategory(
        'Supabase Errors',
        'Supabase initialization failed',
        error,
      );
      return PublicFailure.from(
        error,
        fallback:
            'Cloud services are currently unavailable. Local work remains available.',
      ).message;
    }
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
