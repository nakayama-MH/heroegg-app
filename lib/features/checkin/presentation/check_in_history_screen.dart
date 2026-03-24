import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../models/check_in.dart';
import '../providers/check_in_provider.dart';
import 'widgets/check_in_history_tile.dart';

class CheckInHistoryScreen extends ConsumerWidget {
  const CheckInHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(checkInHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('チェックイン履歴'),
      ),
      body: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(checkInHistoryProvider);
              await ref.read(checkInHistoryProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSummaryRow(history),
                const SizedBox(height: 8),
                ..._buildGroupedList(history),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: '履歴の取得に失敗しました',
          onRetry: () => ref.invalidate(checkInHistoryProvider),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.12,
            child: Image.asset(
              'assets/images/logo_vertical.png',
              width: 72,
              height: 72,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'チェックイン履歴がありません',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'QRコードをスキャンしてチェックインしましょう',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () => context.push('/scan'),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('スキャンする'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(List<CheckIn> history) {
    final totalCount = history.length;
    final uniqueFacilities =
        history.map((c) => c.facilityId).toSet().length;

    int totalMinutes = 0;
    for (final c in history) {
      final end = c.checkedOutAt ?? DateTime.now();
      totalMinutes += end.difference(c.checkedInAt).inMinutes;
    }
    final totalHours = totalMinutes ~/ 60;
    final remainMinutes = totalMinutes % 60;
    final totalTimeStr =
        totalHours > 0 ? '$totalHours時間$remainMinutes分' : '$remainMinutes分';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildStat('$totalCount', '回'),
          _buildDivider(),
          _buildStat('$uniqueFacilities', '施設'),
          _buildDivider(),
          _buildStat(totalTimeStr, '合計'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.border,
    );
  }

  List<Widget> _buildGroupedList(List<CheckIn> history) {
    final grouped = <String, List<CheckIn>>{};
    for (final checkIn in history) {
      grouped.putIfAbsent(checkIn.relativeDateLabel, () => []).add(checkIn);
    }

    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 20, 6),
          child: Text(
            entry.key,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );

      for (final checkIn in entry.value) {
        widgets.add(CheckInHistoryTile(checkIn: checkIn));
      }
    }

    return widgets;
  }
}
