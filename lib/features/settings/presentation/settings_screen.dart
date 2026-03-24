import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final locationPermAsync = ref.watch(locationPermissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _buildSectionHeader('アカウント'),
          _buildGroup([
            _buildTile(
              icon: Icons.person_outline_rounded,
              title: 'アカウント情報',
              subtitle: profileAsync.whenOrNull(
                data: (p) => p?.email ?? '',
              ),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('アプリ設定'),
          _buildGroup([
            _buildTile(
              icon: Icons.location_on_outlined,
              title: '位置情報',
              subtitle: locationPermAsync.whenOrNull(
                data: (perm) {
                  switch (perm) {
                    case LocationPermission.always:
                      return '常に許可';
                    case LocationPermission.whileInUse:
                      return '使用中のみ許可';
                    case LocationPermission.denied:
                      return '拒否';
                    case LocationPermission.deniedForever:
                      return '完全に拒否';
                    case LocationPermission.unableToDetermine:
                      return '未確認';
                  }
                },
              ),
              onTap: () => Geolocator.openAppSettings(),
            ),
            _buildTile(
              icon: Icons.notifications_outlined,
              title: '通知設定',
              subtitle: 'プッシュ通知の設定',
              onTap: () => Geolocator.openAppSettings(),
              isLast: true,
            ),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader('サポート'),
          _buildGroup([
            _buildTile(
              icon: Icons.help_outline_rounded,
              title: 'お問い合わせ',
              subtitle: '一般のお問い合わせ・共創パートナー募集',
              onTap: () => context.push('/contact'),
            ),
            _buildTile(
              icon: Icons.info_outline_rounded,
              title: 'アプリ情報',
              subtitle: 'バージョン 1.0.0',
              onTap: () {},
              isLast: true,
            ),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => _showLogoutDialog(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                ),
              ),
              child: const Text('ログアウト'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Icon(icon, color: AppColors.textSecondary, size: 22),
            title: Text(
                title,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w500)),
            subtitle: subtitle != null
                ? Text(subtitle, style: AppTextStyles.bodySmall)
                : null,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
            onTap: onTap,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, indent: 54, endIndent: 16, color: AppColors.border),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'キャンセル',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authStateNotifierProvider.notifier).signOut();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
