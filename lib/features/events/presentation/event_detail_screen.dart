import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../profile/providers/profile_provider.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../utils/quill_utils.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final profile = ref.watch(profileProvider).valueOrNull;
    final isAdmin = profile?.isStaffOrAdmin ?? false;

    return Scaffold(
      body: eventAsync.when(
        data: (event) => _EventDetailBody(
          event: event,
          eventId: eventId,
          isAdmin: isAdmin,
          ref: ref,
        ),
        loading: () => const LoadingIndicator(message: 'イベントを取得中...'),
        error: (error, _) => ErrorView(
          message: 'イベントの取得に失敗しました',
          onRetry: () => ref.invalidate(eventDetailProvider(eventId)),
        ),
      ),
    );
  }
}

class _EventDetailBody extends StatelessWidget {
  const _EventDetailBody({
    required this.event,
    required this.eventId,
    required this.isAdmin,
    required this.ref,
  });

  final Event event;
  final String eventId;
  final bool isAdmin;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = event.isUpcoming;
    final dateFormat = DateFormat('yyyy年MM月dd日 (E)', 'ja');
    final timeFormat = DateFormat('HH:mm', 'ja');
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final imageHeight = screenWidth * 9 / 16;

    return CustomScrollView(
      slivers: [
        // ─── ヒーロー画像付きSliverAppBar ───
        SliverAppBar(
          expandedHeight: hasImage
              ? imageHeight + topPadding + kToolbarHeight
              : 120,
          pinned: true,
          stretch: true,
          backgroundColor: AppColors.surface,
          foregroundColor: hasImage ? Colors.white : AppColors.textPrimary,
          flexibleSpace: FlexibleSpaceBar(
            background: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surfaceDim,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceDim,
                          child: const Icon(Icons.broken_image_outlined,
                              size: 48, color: AppColors.textTertiary),
                        ),
                      ),
                      // グラデーションオーバーレイ
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x60000000),
                              Colors.transparent,
                              Color(0x90000000),
                            ],
                            stops: [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.08),
                          AppColors.primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
          ),
          actions: [
            if (isAdmin)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: hasImage ? Colors.white : AppColors.textPrimary,
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    context.push('/events/$eventId/edit');
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('イベント削除'),
                        content: const Text('このイベントを削除しますか？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('キャンセル'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('削除'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await ref
                          .read(eventFormProvider.notifier)
                          .deleteEvent(eventId);
                      if (context.mounted) context.pop();
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('編集'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('削除',
                            style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),

        // ─── コンテンツ ───
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── ステータス + タイトル ───
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ステータスバッジ + エリアタグ
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(isUpcoming: isUpcoming),
                        if (event.area != 'その他') _AreaBadge(area: event.area),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      event.title,
                      style: AppTextStyles.headlineLarge,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── 日時・場所カード ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.shadowSm,
                  ),
                  child: Column(
                    children: [
                      // 日付
                      _DetailTile(
                        icon: Icons.calendar_today_rounded,
                        iconColor: AppColors.primary,
                        title: dateFormat.format(event.eventDate),
                        subtitle: '${timeFormat.format(event.eventDate)} 開始',
                      ),
                      const Divider(
                          height: 1, indent: 56, color: AppColors.border),
                      // 場所
                      if (event.locationName.isNotEmpty)
                        _DetailTile(
                          icon: Icons.location_on_rounded,
                          iconColor: AppColors.secondary,
                          title: event.locationName,
                          subtitle: event.area != 'その他' ? event.area : null,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ─── カウントダウン or 終了バナー ───
              if (isUpcoming)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CountdownBanner(eventDate: event.eventDate),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy_rounded,
                            size: 18, color: AppColors.textTertiary),
                        const SizedBox(width: 8),
                        Text(
                          'このイベントは終了しました',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ─── 説明セクション ───
              if (event.description.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('イベント詳細', style: AppTextStyles.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.shadowSm,
                    ),
                    child: QuillEditor.basic(
                      controller: QuillController(
                        document:
                            documentFromDescription(event.description),
                        selection:
                            const TextSelection.collapsed(offset: 0),
                        readOnly: true,
                      ),
                      config: const QuillEditorConfig(
                        showCursor: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],

              // ─── 管理者向け編集ボタン ───
              if (isAdmin) ...[
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/events/$eventId/edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('イベントを編集'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── ステータスバッジ ───
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isUpcoming});
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isUpcoming
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.textTertiary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isUpcoming ? AppColors.success : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isUpcoming ? '開催予定' : '終了',
            style: AppTextStyles.labelSmall.copyWith(
              color: isUpcoming ? AppColors.success : AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── エリアバッジ ───
class _AreaBadge extends StatelessWidget {
  const _AreaBadge({required this.area});
  final String area;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            area == 'オンライン' ? Icons.videocam_outlined : Icons.place_outlined,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            area,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 情報タイル ───
class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                )),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── カウントダウンバナー ───
class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.eventDate});
  final DateTime eventDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = eventDate.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;

    String countdownText;
    if (days > 0) {
      countdownText = '開催まであと $days 日';
    } else if (hours > 0) {
      countdownText = '開催まであと $hours 時間';
    } else if (diff.inMinutes > 0) {
      countdownText = 'まもなく開催';
    } else {
      countdownText = '開催中';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF3DB8D4)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            countdownText,
            style: AppTextStyles.labelLarge.copyWith(
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
