import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../checkin/providers/check_in_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/egg_facility.dart';
import '../providers/home_provider.dart';

class FacilityDetailScreen extends ConsumerWidget {
  const FacilityDetailScreen({super.key, required this.facilityId});

  final String facilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityAsync = ref.watch(facilityDetailProvider(facilityId));
    final activeCheckIn = ref.watch(activeCheckInProvider);

    return Scaffold(
      body: facilityAsync.when(
        data: (facility) {
          if (facility == null) {
            return const ErrorView(message: '施設が見つかりませんでした');
          }
          return _FacilityDetailBody(
            facility: facility,
            activeCheckIn: activeCheckIn,
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: '施設情報の取得に失敗しました',
          onRetry: () => ref.invalidate(facilityDetailProvider(facilityId)),
        ),
      ),
    );
  }
}

class _FacilityDetailBody extends ConsumerWidget {
  const _FacilityDetailBody({
    required this.facility,
    required this.activeCheckIn,
  });

  final EggFacility facility;
  final AsyncValue activeCheckIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPosition = ref.watch(userLocationProvider).valueOrNull;
    final isCheckedInHere =
        activeCheckIn.valueOrNull?.facilityId == facility.id;
    final profile = ref.watch(profileProvider).valueOrNull;
    final canShowQr = profile?.isStaffOrAdmin ?? false;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // 画像
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0.5,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: facility.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: facility.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surfaceDim,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // チェックイン中ステータス
                    if (isCheckedInHere) ...[
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'チェックイン中',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 施設名
                    Text(facility.name, style: AppTextStyles.headlineLarge),
                    const SizedBox(height: 10),

                    // 住所（テキストとして自然に配置）
                    Text(
                      facility.address,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    // 距離（住所のすぐ下にインラインで）
                    if (facility.distance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '現在地から ${facility.distanceText}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    // 説明
                    if (facility.description.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        height: 1,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        facility.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.7,
                        ),
                      ),
                    ],

                    // マップ
                    const SizedBox(height: 24),
                    Container(
                      height: 1,
                      color: AppColors.border,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        final url = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${facility.latitude},${facility.longitude}',
                        );
                        launchUrl(url, mode: LaunchMode.externalApplication);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 160,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                        facility.latitude, facility.longitude),
                                    initialZoom: 15.0,
                                    interactionOptions:
                                        const InteractionOptions(
                                      flags: InteractiveFlag.none,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.metaheroes.heroegg',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(facility.latitude,
                                              facility.longitude),
                                          width: 36,
                                          height: 36,
                                          child: Image.asset(
                                            'assets/images/hero_egg.png',
                                            width: 36,
                                            height: 36,
                                          ),
                                        ),
                                        if (userPosition != null)
                                          Marker(
                                            point: LatLng(
                                                userPosition.latitude,
                                                userPosition.longitude),
                                            width: 14,
                                            height: 14,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // タップヒント（右下に小さく）
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Google Maps で開く',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 管理者向けQRボタン
                    if (canShowQr) ...[
                      const SizedBox(height: 24),
                      Container(
                        height: 1,
                        color: AppColors.border,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => context.push(
                          '/qr/${facility.id}?name=${Uri.encodeComponent(facility.name)}',
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_rounded,
                                size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Text(
                              'この施設のQRコードを表示',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded,
                                size: 20, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ],

                    // ボトム余白（CTAボタン分 + SafeArea）
                    SizedBox(height: bottomPadding + 100),
                  ],
                ),
              ),
            ),
          ],
        ),

        // 固定CTA
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: isCheckedInHere
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded,
                              size: 18, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'チェックイン済み',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    )
                  : FilledButton(
                      onPressed: () => context.push('/scan'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'チェックイン',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.surfaceDim,
      child: Center(
        child: Image.asset(
          'assets/images/hero_egg.png',
          width: 64,
          height: 64,
          opacity: const AlwaysStoppedAnimation(0.15),
        ),
      ),
    );
  }
}
