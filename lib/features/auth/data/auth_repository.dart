import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  static String get _redirectUrl => kIsWeb
      ? 'https://app.heroegg.com/auth/callback'
      : 'io.heroegg://login-callback';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    String? gender,
    String? region,
    String? birthDate,
    String? phone,
  }) async {
    return await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: _redirectUrl,
      data: {
        if (displayName != null) 'display_name': displayName,
        if (gender != null) 'gender': gender,
        if (region != null) 'region': region,
        if (birthDate != null) 'birth_date': birthDate,
        if (phone != null) 'phone': phone,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(email, redirectTo: _redirectUrl);
  }
}
