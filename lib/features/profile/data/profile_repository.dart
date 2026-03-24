import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> getProfile(String userId) async {
    final response = await _client
        .from(SupabaseConstants.profilesTable)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  Future<void> updateProfile(Profile profile) async {
    await _client
        .from(SupabaseConstants.profilesTable)
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  Future<String> uploadAvatar(String userId, File imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final path = '$userId/avatar.$ext';

    await _client.storage.from('avatars').upload(
          path,
          imageFile,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from('avatars').getPublicUrl(path);

    await _client
        .from(SupabaseConstants.profilesTable)
        .update({'avatar_url': url}).eq('id', userId);

    return url;
  }
}
