import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/check_in.dart';

class CheckInHistoryTile extends StatelessWidget {
  const CheckInHistoryTile({super.key, required this.checkIn});

  final CheckIn checkIn;

  static const _avatarColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
    Color(0xFF8B5CF6),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context) {
    final name = checkIn.facilityName ?? '施設';
    final initial = name.characters.first;
    final avatarColor =
        _avatarColors[name.hashCode.abs() % _avatarColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: AppTextStyles.titleMedium.copyWith(
                  color: avatarColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    checkIn.relativeDateTimeLabel,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              checkIn.durationText,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
