import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/home_provider.dart';
import '../../checkin/presentation/widgets/check_in_status_banner.dart';
import 'widgets/egg_list_view.dart';
import 'widgets/egg_map_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userLocationProvider.notifier).getCurrentLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(homeViewModeProvider);
    final facilitiesAsync = ref.watch(nearbyFacilitiesProvider);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          toolbarHeight: 56,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: Image.asset(
            'assets/images/logo_horizontal.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          actions: [
            IconButton(
              icon: Icon(
                viewMode == HomeViewMode.list
                    ? Icons.map_outlined
                    : Icons.list_rounded,
                size: 22,
              ),
              onPressed: () {
                ref.read(homeViewModeProvider.notifier).state =
                    viewMode == HomeViewMode.list
                        ? HomeViewMode.map
                        : HomeViewMode.list;
              },
              tooltip: viewMode == HomeViewMode.list ? '地図表示' : 'リスト表示',
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CheckInStatusBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Text(
                  '近くのEgg施設',
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(width: 8),
                if (facilitiesAsync.valueOrNull != null &&
                    facilitiesAsync.valueOrNull!.isNotEmpty)
                  Text(
                    '${facilitiesAsync.valueOrNull!.length}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: facilitiesAsync.when(
              data: (facilities) {
                if (facilities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: 0.15,
                          child: Image.asset(
                            'assets/images/hero_egg.png',
                            width: 64,
                            height: 64,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '近くにEgg施設が見つかりませんでした',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return viewMode == HomeViewMode.list
                    ? EggListView(facilities: facilities)
                    : EggMapView(facilities: facilities);
              },
              loading: () => const LoadingIndicator(message: '施設を検索中...'),
              error: (error, _) {
                return ErrorView(
                message: '施設の取得に失敗しました',
                onRetry: () => ref.invalidate(nearbyFacilitiesProvider),
              );
              },
            ),
          ),
        ],
      ),
    );
  }
}
