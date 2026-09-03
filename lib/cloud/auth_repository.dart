import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  /// Signs out from the provider and clears the local session.
  ///
  /// A global sign-out revokes the user's other sessions when the network is
  /// available. The UI may fall back to a local sign-out so a failed network
  /// request never traps the user in a stale local session.
  Future<void> signOut({bool global = true});
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) {
      throw const AuthException('Authentication did not return a user.');
    }
  }

  @override
  Future<void> signOut({bool global = true}) {
    return _client.auth.signOut(
      scope: global ? SignOutScope.global : SignOutScope.local,
    );
  }
}
