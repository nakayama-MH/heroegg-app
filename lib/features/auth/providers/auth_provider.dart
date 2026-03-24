import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseAuthProvider));
});

final authStateNotifierProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<void>>((ref) {
  return AuthStateNotifier(ref.watch(authRepositoryProvider));
});

class AuthStateNotifier extends StateNotifier<AsyncValue<void>> {
  AuthStateNotifier(this._repository) : super(const AsyncValue.data(null));

  final AuthRepository _repository;

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
    String? gender,
    String? region,
    String? birthDate,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signUp(
        email: email,
        password: password,
        displayName: displayName,
        gender: gender,
        region: region,
        birthDate: birthDate,
        phone: phone,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(_mapAuthError(e), st);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signIn(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(_mapAuthError(e), st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repository.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _repository.resetPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(_mapAuthError(e), st);
    }
  }

  String _mapAuthError(Object error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'メールアドレスまたはパスワードが正しくありません';
        case 'User already registered':
          return 'このメールアドレスは既に登録されています';
        case 'Email not confirmed':
          return 'メールアドレスの確認が完了していません';
        default:
          return error.message;
      }
    }
    return '予期せぬエラーが発生しました';
  }
}
