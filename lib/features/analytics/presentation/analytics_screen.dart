import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await Supabase.instance.client.rpc('get_analytics');
  return response as Map<String, dynamic>;
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('分析ダッシュボード', style: AppTextStyles.headlineSmall),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(analyticsProvider),
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (data) => _buildDashboard(data),
        loading: () => const LoadingIndicator(message: 'データを集計中...'),
        error: (e, _) => ErrorView(
          message: '分析データの取得に失敗しました',
          onRetry: () => ref.invalidate(analyticsProvider),
        ),
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> data) {
    final members = data['members'] as Map<String, dynamic>;
    final checkins = data['checkins'] as Map<String, dynamic>;
    final events = data['events'] as Map<String, dynamic>;
    final inquiries = data['inquiries'] as Map<String, dynamic>;
    final facilities = data['facilities'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // === KPI概要カード ===
        _SectionTitle(title: 'サマリー'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
          children: [
            _KpiCard(label: '総会員数', value: '${members['total']}', icon: Icons.people_rounded, color: AppColors.primary),
            _KpiCard(label: 'チェックイン', value: '${checkins['total']}', icon: Icons.qr_code_scanner_rounded, color: AppColors.secondary),
            _KpiCard(label: '施設数', value: '${facilities['total']}', icon: Icons.location_city_rounded, color: AppColors.tertiary),
            _KpiCard(label: 'イベント', value: '${events['total']}', icon: Icons.event_rounded, color: const Color(0xFF8B5CF6)),
            _KpiCard(label: '現在滞在中', value: '${checkins['active_now']}', icon: Icons.sensors_rounded, color: AppColors.success),
            _KpiCard(label: 'リピーター', value: '${checkins['repeat_users']}', icon: Icons.repeat_rounded, color: const Color(0xFFEC4899)),
          ],
        ),

        const SizedBox(height: 28),

        // === 会員分析 ===
        _SectionTitle(title: '会員分析'),
        const SizedBox(height: 8),
        _BreakdownCard(
          title: '性別分布',
          icon: Icons.wc_rounded,
          items: _parseItems(members['by_gender'], labelMap: {
            'male': 'おとこ', 'female': 'おんな', 'other': 'そのほか', 'unknown': '未設定',
          }),
          total: members['total'] as int,
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '年代分布',
          icon: Icons.cake_rounded,
          items: _parseItems(members['by_age_group']),
          total: members['total'] as int,
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '地域分布',
          icon: Icons.map_rounded,
          items: _parseItems(members['by_region']),
          total: members['total'] as int,
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '会員ランク',
          icon: Icons.star_rounded,
          items: _parseItems(members['by_member_rank']),
          total: members['total'] as int,
        ),
        const SizedBox(height: 12),
        _TimeSeriesCard(
          title: '月別新規登録',
          icon: Icons.trending_up_rounded,
          items: _parseItems(members['by_month']),
        ),

        const SizedBox(height: 28),

        // === チェックイン分析 ===
        _SectionTitle(title: 'チェックイン分析'),
        const SizedBox(height: 8),
        _buildInfoRow('総チェックイン数', '${checkins['total']}回'),
        _buildInfoRow('ユニークユーザー数', '${checkins['unique_users']}人'),
        _buildInfoRow('平均滞在時間', '${checkins['avg_duration_minutes']}分'),
        _buildInfoRow('リピーター数', '${checkins['repeat_users']}人'),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '施設別チェックイン',
          icon: Icons.location_city_rounded,
          items: _parseItems(checkins['by_facility']),
          total: checkins['total'] as int,
        ),
        const SizedBox(height: 12),
        _BreakdownCard(
          title: '曜日別チェックイン',
          icon: Icons.calendar_view_week_rounded,
          items: _parseItems(checkins['by_weekday']),
          total: checkins['total'] as int,
        ),
        const SizedBox(height: 12),
        _TimeSeriesCard(
          title: '時間帯別チェックイン',
          icon: Icons.schedule_rounded,
          items: _parseItems(checkins['by_hour'], labelSuffix: '時'),
        ),
        const SizedBox(height: 12),
        _TimeSeriesCard(
          title: '月別チェックイン',
          icon: Icons.trending_up_rounded,
          items: _parseItems(checkins['by_month']),
        ),

        const SizedBox(height: 28),

        // === イベント分析 ===
        _SectionTitle(title: 'イベント分析'),
        const SizedBox(height: 8),
        _buildInfoRow('総イベント数', '${events['total']}件'),
        _buildInfoRow('開催予定', '${events['upcoming']}件'),
        _buildInfoRow('終了', '${events['completed']}件'),
        const SizedBox(height: 12),
        _TimeSeriesCard(
          title: '月別イベント開催数',
          icon: Icons.event_rounded,
          items: _parseItems(events['by_month']),
        ),

        const SizedBox(height: 28),

        // === お問い合わせ分析 ===
        _SectionTitle(title: 'お問い合わせ'),
        const SizedBox(height: 8),
        _buildInfoRow('総件数', '${inquiries['total']}件'),
        if (inquiries['by_type'] != null) ...[
          const SizedBox(height: 12),
          _BreakdownCard(
            title: '種類別',
            icon: Icons.category_rounded,
            items: _parseItems(inquiries['by_type'], labelMap: {
              'general': '一般', 'partner': 'パートナー', 'bug': 'バグ', 'feature': '機能要望',
            }),
            total: inquiries['total'] as int,
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppColors.shadowSm,
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            Text(value, style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  List<_AnalyticsItem> _parseItems(
    dynamic data, {
    Map<String, String>? labelMap,
    String labelSuffix = '',
  }) {
    if (data == null) return [];
    return (data as List).map((item) {
      final raw = item['label']?.toString() ?? '不明';
      final label = (labelMap?[raw] ?? raw) + labelSuffix;
      return _AnalyticsItem(label: label, value: item['value'] as int? ?? 0);
    }).toList();
  }
}

// === UI Components ===

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700));
  }
}

class _AnalyticsItem {
  const _AnalyticsItem({required this.label, required this.value});
  final String label;
  final int value;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(
            color: color, fontWeight: FontWeight.w700, fontSize: 22,
          )),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary, fontSize: 10,
          ), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.title, required this.icon, required this.items, required this.total});
  final String title;
  final IconData icon;
  final List<_AnalyticsItem> items;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('データなし', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary))
          else
            ...items.map((item) {
              final pct = total > 0 ? (item.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.label, style: AppTextStyles.bodySmall)),
                        Text('${item.value}', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TimeSeriesCard extends StatelessWidget {
  const _TimeSeriesCard({required this.title, required this.icon, required this.items});
  final String title;
  final IconData icon;
  final List<_AnalyticsItem> items;

  @override
  Widget build(BuildContext context) {
    final maxValue = items.isEmpty ? 1 : items.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('データなし', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary))
          else
            SizedBox(
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: items.map((item) {
                  final ratio = maxValue > 0 ? item.value / maxValue : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${item.value}',
                            style: AppTextStyles.labelSmall.copyWith(fontSize: 9, color: AppColors.primary),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: ratio < 0.05 ? 0.05 : ratio,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label.length > 7 ? '${item.label.substring(item.label.length - 2)}' : item.label,
                            style: AppTextStyles.labelSmall.copyWith(fontSize: 8, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
