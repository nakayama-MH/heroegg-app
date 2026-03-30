import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/profile_repository.dart';
import '../models/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfile(user.id);
});

final profileUpdateProvider =
    StateNotifierProvider<ProfileUpdateNotifier, AsyncValue<void>>((ref) {
  return ProfileUpdateNotifier(ref.watch(profileRepositoryProvider), ref);
});

final avatarUploadProvider =
    StateNotifierProvider<AvatarUploadNotifier, AsyncValue<void>>((ref) {
  return AvatarUploadNotifier(ref);
});

class AvatarUploadNotifier extends StateNotifier<AsyncValue<void>> {
  AvatarUploadNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<String> upload(Uint8List bytes, String ext) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('ログインが必要です');

      final repository = _ref.read(profileRepositoryProvider);
      final url = await repository.uploadAvatar(user.id, bytes, ext);
      _ref.invalidate(profileProvider);
      state = const AsyncValue.data(null);
      return url;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

class ProfileUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  ProfileUpdateNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  final ProfileRepository _repository;
  final Ref _ref;

  Future<void> updateProfile(Profile profile) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateProfile(profile);
      _ref.invalidate(profileProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
