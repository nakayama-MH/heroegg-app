import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../models/egg_facility.dart';
import '../../providers/home_provider.dart';

class EggMapView extends ConsumerStatefulWidget {
  const EggMapView({super.key, required this.facilities});

  final List<EggFacility> facilities;

  @override
  ConsumerState<EggMapView> createState() => _EggMapViewState();
}

class _EggMapViewState extends ConsumerState<EggMapView> {
  static const _sheetMinSize = 0.12;
  static const _sheetInitialSize = 0.4;
  static const _sheetMaxSize = 0.75;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _showList = false;
  bool _hasMovedToUser = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(facilitySearchQueryProvider.notifier).state =
          _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sheetController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _moveToCurrentLocation() async {
    final position = ref.read(userLocationProvider).valueOrNull;
    if (position != null) {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } else {
      // 位置情報を再取得
      await ref.read(userLocationProvider.notifier).getCurrentLocation();
      final newPosition = ref.read(userLocationProvider).valueOrNull;
      if (newPosition != null && mounted) {
        _mapController.move(
          LatLng(newPosition.latitude, newPosition.longitude),
          15.0,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('位置情報を取得できませんでした'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _moveToFacility(EggFacility facility) {
    _mapController.move(
      LatLng(facility.latitude, facility.longitude),
      16.0,
    );
    // シートを閉じてからマーカー情報表示
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        _sheetMinSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _showFacilityInfo(context, facility);
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(userLocationProvider);
    final userPosition = locationState.valueOrNull;
    final filteredAsync = ref.watch(filteredFacilitiesProvider);
    final filteredFacilities = filteredAsync.valueOrNull ?? widget.facilities;

    final center = userPosition != null
        ? LatLng(userPosition.latitude, userPosition.longitude)
        : widget.facilities.isNotEmpty
            ? LatLng(
                widget.facilities.first.latitude,
                widget.facilities.first.longitude,
              )
            : const LatLng(35.6812, 139.7671);

    // 位置情報が取得できたら自動で現在地に移動（初回のみ）
    ref.listen<AsyncValue<Position?>>(userLocationProvider, (prev, next) {
      final pos = next.valueOrNull;
      if (pos != null && !_hasMovedToUser) {
        _hasMovedToUser = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(
              LatLng(pos.latitude, pos.longitude),
              14.0,
            );
          }
        });
      }
    });

    return Stack(
      children: [
        // マップ
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            onTap: (_, __) {
              FocusScope.of(context).unfocus();
            },
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
                    point: LatLng(
                        userPosition.latitude, userPosition.longitude),
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ...filteredFacilities.map(
                  (facility) => Marker(
                    point: LatLng(facility.latitude, facility.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showFacilityInfo(context, facility),
                      child: Image.asset(
                        'assets/images/hero_egg.png',
                        width: 40,
                        height: 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 検索バー
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.shadowMd,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '施設名・住所で検索',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: AppTextStyles.bodyMedium,
                );
              },
            ),
          ),
        ),

        // 現在地ボタン
        Positioned(
          right: 16,
          bottom: _showList ? 340 : 100,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapActionButton(
                  icon: Icons.my_location,
                  onPressed: _moveToCurrentLocation,
                  tooltip: '現在地に移動',
                ),
                const SizedBox(height: 8),
                _MapActionButton(
                  icon: _showList
                      ? Icons.map_outlined
                      : Icons.format_list_bulleted,
                  onPressed: () {
                    setState(() => _showList = !_showList);
                    if (_showList && _sheetController.isAttached) {
                      _sheetController.animateTo(
                        _sheetInitialSize,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  tooltip: _showList ? '一覧を閉じる' : '施設一覧',
                ),
              ],
            ),
          ),
        ),

        // 施設一覧（ドラッグ可能なボトムシート）
        if (_showList)
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _sheetInitialSize,
            minChildSize: _sheetMinSize,
            maxChildSize: _sheetMaxSize,
            snap: true,
            snapSizes: const [_sheetMinSize, _sheetInitialSize, _sheetMaxSize],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: AppColors.shadowLg,
                ),
                child: Column(
                  children: [
                    // ドラッグハンドル
                    GestureDetector(
                      onTap: () {
                        if (_sheetController.isAttached) {
                          final currentSize = _sheetController.size;
                          if (currentSize < 0.3) {
                            _sheetController.animateTo(_sheetInitialSize,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          } else {
                            _sheetController.animateTo(_sheetMinSize,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut);
                          }
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ヘッダー
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Row(
                        children: [
                          Text(
                            '近くの施設',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredFacilities.length}件',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () =>
                                setState(() => _showList = false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    // 施設リスト
                    Expanded(
                      child: filteredFacilities.isEmpty
                          ? Center(
                              child: Text(
                                '該当する施設が見つかりません',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: filteredFacilities.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final facility = filteredFacilities[index];
                                return _FacilityListTile(
                                  facility: facility,
                                  onTap: () => _moveToFacility(facility),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/facility/${facility.id}');
                },
                child: const Text('詳細を見る'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// マップ上のアクションボタン
class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppColors.shadowMd,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primary, size: 22),
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}

/// 施設リストの各行
class _FacilityListTile extends StatelessWidget {
  const _FacilityListTile({
    required this.facility,
    required this.onTap,
  });

  final EggFacility facility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Image.asset(
              'assets/images/hero_egg.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 12),
            // 施設情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    facility.name,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facility.address,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (facility.distance != null) ...[
              const SizedBox(width: 8),
              Text(
                facility.distanceText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
