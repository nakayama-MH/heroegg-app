import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import 'widgets/event_card.dart';

const _areaFilters = ['すべて', '関西', '関東'];
const _statusFilters = ['すべて', '開催予定', '終了'];

class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  String _selectedArea = 'すべて';
  String _selectedStatus = 'すべて';

  List<Event> _applyFilters(List<Event> events) {
    var result = events.toList();

    // ステータスフィルター
    if (_selectedStatus == '開催予定') {
      result = result.where((e) => e.isUpcoming).toList();
    } else if (_selectedStatus == '終了') {
      result = result.where((e) => !e.isUpcoming).toList();
    }

    // エリアフィルター
    if (_selectedArea != 'すべて') {
      result = result.where((e) => e.area == _selectedArea).toList();
    }

    // 開催予定を先頭に、その中では日付昇順。終了は日付降順。
    final upcoming = result.where((e) => e.isUpcoming).toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final past = result.where((e) => !e.isUpcoming).toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));

    return [...upcoming, ...past];
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final isAdmin = profile?.isStaffOrAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('イベント', style: AppTextStyles.headlineSmall),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => context.push('/events/create'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_busy_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '現在予定されているイベントはありません',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/events/create'),
                      icon: const Icon(Icons.add),
                      label: const Text('イベントを作成'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          final filtered = _applyFilters(events);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(eventsProvider.future),
            child: Column(
              children: [
                // ステータスフィルター
                _buildFilterRow(
                  icon: Icons.event_note_rounded,
                  filters: _statusFilters,
                  selected: _selectedStatus,
                  onSelected: (v) => setState(() => _selectedStatus = v),
                  countFn: (label) {
                    if (label == 'すべて') return events.length;
                    if (label == '開催予定') return events.where((e) => e.isUpcoming).length;
                    return events.where((e) => !e.isUpcoming).length;
                  },
                ),
                const SizedBox(height: 4),
                // エリアフィルター
                _buildFilterRow(
                  icon: Icons.location_on_outlined,
                  filters: _areaFilters,
                  selected: _selectedArea,
                  onSelected: (v) => setState(() => _selectedArea = v),
                  countFn: (label) {
                    if (label == 'すべて') return events.length;
                    return events.where((e) => e.area == label).length;
                  },
                ),
                const SizedBox(height: 8),
                // イベントリスト
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            '該当するイベントはありません',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return EventCard(
                              event: filtered[index],
                              onTap: () => context.push(
                                '/events/${filtered[index].id}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(message: 'イベントを取得中...'),
        error: (error, _) => ErrorView(
          message: 'イベントの取得に失敗しました',
          onRetry: () => ref.invalidate(eventsProvider),
        ),
      ),
    );
  }

  Widget _buildFilterRow({
    required IconData icon,
    required List<String> filters,
    required String selected,
    required ValueChanged<String> onSelected,
    required int Function(String) countFn,
  }) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Icon(icon, size: 16, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4, right: 20),
              itemCount: filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final label = filters[index];
                final isSelected = selected == label;
                final count = countFn(label);

                return FilterChip(
                  label: Text('$label ($count)'),
                  selected: isSelected,
                  onSelected: (_) => onSelected(label),
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primary,
                  labelStyle: AppTextStyles.labelSmall.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
