import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthRepository {
  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> updatePassword({required String password});

  /// Signs out from the current device by default.
  ///
  /// Pass [global] as true only for an explicit "sign out all devices" action.
  /// Keeping ordinary sign-out local lets the same teacher stay signed in on
  /// their other trusted devices.
  Future<void> signOut({bool global = false});
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
  Future<void> updatePassword({required String password}) async {
    final response = await _client.auth.updateUser(
      UserAttributes(password: password),
    );
    if (response.user == null) {
      throw const AuthException('Password update did not return a user.');
    }
  }

  @override
  Future<void> signOut({bool global = false}) {
    return _client.auth.signOut(
      scope: global ? SignOutScope.global : SignOutScope.local,
    );
  }
}
