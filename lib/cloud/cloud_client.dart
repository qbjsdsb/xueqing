import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_config.dart';
import 'secure_supabase_local_storage.dart';

class CloudClient {
  CloudClient._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize(
    CloudConfig config, {
    bool requireSecureEndpoint = false,
  }) async {
    config.validate(
      requireConfigured: requireSecureEndpoint,
      requireHttps: requireSecureEndpoint,
      requireAllowedHost: requireSecureEndpoint,
    );
    if (_initialized) {
      return;
    }

    if (!config.isConfigured) {
      return;
    }

    await Supabase.initialize(
      url: config.url.trim(),
      publishableKey: config.publishableKey.trim(),
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSupabaseLocalStorage(),
      ),
    );
    _initialized = true;
  }
}
