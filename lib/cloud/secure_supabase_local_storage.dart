import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureSupabaseLocalStorage extends LocalStorage {
  SecureSupabaseLocalStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() {
    return _storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<String?> accessToken() {
    return _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(
      key: supabasePersistSessionKey,
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() {
    return _storage.delete(key: supabasePersistSessionKey);
  }
}
