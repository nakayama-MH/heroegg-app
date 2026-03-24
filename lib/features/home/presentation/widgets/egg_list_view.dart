import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/egg_card.dart';
import '../../models/egg_facility.dart';

class EggListView extends StatelessWidget {
  const EggListView({super.key, required this.facilities});

  final List<EggFacility> facilities;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: facilities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final facility = facilities[index];
        return EggCard(
          name: facility.name,
          address: facility.address,
          imageUrl: facility.imageUrl,
          distance: facility.distance != null ? facility.distanceText : null,
          onTap: () => context.push('/facility/${facility.id}'),
        );
      },
    );
  }
}
