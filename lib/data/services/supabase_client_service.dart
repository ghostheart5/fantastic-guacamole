import 'dart:async';

import 'package:fantastic_guacamole/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class SupabaseClientService {
  const SupabaseClientService();

  Future<String?> initialize({required bool isMockMode}) async {
    if (isMockMode || !Env.isSupabaseConfigured) {
      return null;
    }

    try {
      await sb.Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      ).timeout(const Duration(seconds: 12));
      return null;
    } on TimeoutException {
      return 'Supabase initialization timed out. Auth will be unavailable.';
    } on Exception catch (error) {
      return 'Supabase initialization failed: $error';
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
