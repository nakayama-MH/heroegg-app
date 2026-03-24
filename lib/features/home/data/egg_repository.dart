import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../models/egg_facility.dart';

class EggRepository {
  EggRepository(this._client);

  final SupabaseClient _client;

  Future<List<EggFacility>> getNearbyFacilities({
    required double latitude,
    required double longitude,
    double radiusMeters = 50000,
  }) async {
    final response = await _client.rpc(
      SupabaseConstants.getNearbyFacilitiesRpc,
      params: {
        'user_lat': latitude,
        'user_lng': longitude,
        'radius_meters': radiusMeters,
      },
    );

    return (response as List)
        .map((json) => EggFacility.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<EggFacility?> getFacilityById(String id) async {
    final response = await _client
        .from(SupabaseConstants.eggFacilitiesTable)
        .select('id, name, description, address, latitude, longitude, image_url')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return EggFacility.fromJson(response);
  }

  Future<List<EggFacility>> getAllFacilities() async {
    final response = await _client
        .from(SupabaseConstants.eggFacilitiesTable)
        .select('id, name, description, address, latitude, longitude, image_url')
        .order('name');

    return (response as List)
        .map((json) => EggFacility.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
