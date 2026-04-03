import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseAuthProvider = Provider<GoTrueClient>((ref) {
  return ref.watch(supabaseClientProvider).auth;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseAuthProvider).onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  // 認証状態の変更を監視して、ログイン切替時にユーザー情報を更新する
  ref.watch(authStateProvider);
  return ref.watch(supabaseAuthProvider).currentUser;
});
