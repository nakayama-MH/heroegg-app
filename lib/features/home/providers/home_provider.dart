import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/egg_repository.dart';
import '../models/egg_facility.dart';

final eggRepositoryProvider = Provider<EggRepository>((ref) {
  return EggRepository(ref.watch(supabaseClientProvider));
});

final userLocationProvider =
    StateNotifierProvider<LocationNotifier, AsyncValue<Position?>>((ref) {
  return LocationNotifier();
});

class LocationNotifier extends StateNotifier<AsyncValue<Position?>> {
  LocationNotifier() : super(const AsyncValue.data(null));

  Future<void> getCurrentLocation() async {
    state = const AsyncValue.loading();
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const AsyncValue.data(null);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = const AsyncValue.data(null);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = const AsyncValue.data(null);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      state = AsyncValue.data(position);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final nearbyFacilitiesProvider =
    FutureProvider<List<EggFacility>>((ref) async {
  final locationState = ref.watch(userLocationProvider);
  final repository = ref.watch(eggRepositoryProvider);
  final position = locationState.valueOrNull;

  if (position != null) {
    final nearby = await repository.getNearbyFacilities(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    // 近くに施設がない場合は全施設を表示
    if (nearby.isEmpty) {
      return repository.getAllFacilities();
    }
    return nearby;
  } else {
    return repository.getAllFacilities();
  }
});

final facilityDetailProvider =
    FutureProvider.family<EggFacility?, String>((ref, id) {
  return ref.watch(eggRepositoryProvider).getFacilityById(id);
});

final facilitySearchQueryProvider = StateProvider<String>((ref) => '');

final filteredFacilitiesProvider =
    Provider<AsyncValue<List<EggFacility>>>((ref) {
  final facilitiesAsync = ref.watch(nearbyFacilitiesProvider);
  final query = ref.watch(facilitySearchQueryProvider).toLowerCase();

  return facilitiesAsync.whenData((facilities) {
    if (query.isEmpty) return facilities;
    return facilities
        .where((f) =>
            f.name.toLowerCase().contains(query) ||
            f.address.toLowerCase().contains(query))
        .toList();
  });
});

final homeViewModeProvider = StateProvider<HomeViewMode>((ref) {
  return HomeViewMode.list;
});

enum HomeViewMode { list, map }
