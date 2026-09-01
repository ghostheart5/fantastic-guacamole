import 'package:fantastic_guacamole/config/env.dart';
import 'package:fantastic_guacamole/core/debug/logger.dart';
import 'package:fantastic_guacamole/core/errors/public_failure.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseClientService {
  const SupabaseClientService({
    @visibleForTesting Future<String?> Function()? initializeClient,
    @visibleForTesting bool? isConfigured,
  }) : _initializeClientOverride = initializeClient,
       _isConfiguredOverride = isConfigured;

  final Future<String?> Function()? _initializeClientOverride;
  final bool? _isConfiguredOverride;

  static Future<String?>? _initialization;

  @visibleForTesting
  static void resetForTesting() {
    _initialization = null;
  }

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode || !(_isConfiguredOverride ?? Env.isSupabaseConfigured)) {
      return null;
    }
    final Future<String?> initialization = _initialization ??=
        _initializeClientOverride?.call() ?? _initializeOnce();
    final String? issue = await initialization;
    if (issue != null && identical(_initialization, initialization)) {
      _initialization = null;
    }
    return issue;
  }

  Future<String?> _initializeOnce() async {
    try {
      await sb.Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      return null;
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
