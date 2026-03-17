import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/home_provider.dart';
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
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo_horizontal.png',
          height: 32,
        ),
        actions: [
          IconButton(
            icon: Icon(
              viewMode == HomeViewMode.list
                  ? Icons.map_outlined
                  : Icons.list_rounded,
            ),
            onPressed: () {
              ref.read(homeViewModeProvider.notifier).state =
                  viewMode == HomeViewMode.list
                      ? HomeViewMode.map
                      : HomeViewMode.list;
            },
            tooltip: viewMode == HomeViewMode.list ? '地図表示' : 'リスト表示',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              '近くのEgg施設',
              style: AppTextStyles.headlineSmall,
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
                        const Icon(
                          Icons.egg_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
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
              error: (error, _) => ErrorView(
                message: '施設の取得に失敗しました',
                onRetry: () => ref.invalidate(nearbyFacilitiesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
