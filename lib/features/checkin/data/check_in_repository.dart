import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../models/check_in.dart';

class CheckInRepository {
  CheckInRepository(this._client);

  final SupabaseClient _client;

  static const _selectWithFacility =
      '*, egg_facilities(name, address)';

  Future<CheckIn?> getActiveCheckIn(String userId) async {
    final response = await _client
        .from(SupabaseConstants.checkInsTable)
        .select(_selectWithFacility)
        .eq('user_id', userId)
        .isFilter('checked_out_at', null)
        .maybeSingle();

    if (response == null) return null;
    return CheckIn.fromJson(response);
  }

  Future<List<CheckIn>> getCheckInHistory(String userId) async {
    final response = await _client
        .from(SupabaseConstants.checkInsTable)
        .select(_selectWithFacility)
        .eq('user_id', userId)
        .not('checked_out_at', 'is', null)
        .order('checked_in_at', ascending: false);

    return (response as List)
        .map((json) => CheckIn.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CheckIn> checkIn(String userId, String facilityId) async {
    final insertResponse = await _client
        .from(SupabaseConstants.checkInsTable)
        .insert({
          'user_id': userId,
          'facility_id': facilityId,
        })
        .select(_selectWithFacility)
        .single();

    return CheckIn.fromJson(insertResponse);
  }

  Future<void> checkOut(String checkInId) async {
    await _client
        .from(SupabaseConstants.checkInsTable)
        .update({'checked_out_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', checkInId);
  }

  Future<bool> facilityExists(String facilityId) async {
    final response = await _client
        .from(SupabaseConstants.eggFacilitiesTable)
        .select('id')
        .eq('id', facilityId)
        .maybeSingle();

    return response != null;
  }
}
