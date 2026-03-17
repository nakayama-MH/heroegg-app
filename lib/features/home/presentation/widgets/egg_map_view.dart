import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/egg_facility.dart';
import '../../providers/home_provider.dart';

class EggMapView extends ConsumerWidget {
  const EggMapView({super.key, required this.facilities});

  final List<EggFacility> facilities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(userLocationProvider);
    final userPosition = locationState.valueOrNull;

    final center = userPosition != null
        ? LatLng(userPosition.latitude, userPosition.longitude)
        : facilities.isNotEmpty
            ? LatLng(facilities.first.latitude, facilities.first.longitude)
            : const LatLng(35.6812, 139.7671); // Tokyo default

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.metaheroes.heroegg',
        ),
        MarkerLayer(
          markers: [
            if (userPosition != null)
              Marker(
                point:
                    LatLng(userPosition.latitude, userPosition.longitude),
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ...facilities.map(
              (facility) => Marker(
                point: LatLng(facility.latitude, facility.longitude),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showFacilityInfo(context, facility),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.egg_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFacilityInfo(BuildContext context, EggFacility facility) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(facility.name, style: AppTextStyles.headlineSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    facility.address,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
            if (facility.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(facility.description, style: AppTextStyles.bodyMedium),
            ],
            if (facility.distance != null) ...[
              const SizedBox(height: 8),
              Text(
                '現在地から ${facility.distanceText}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
