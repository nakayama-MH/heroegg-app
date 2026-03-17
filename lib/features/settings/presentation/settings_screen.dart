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
        title: Text('設定', style: AppTextStyles.headlineSmall),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('アカウント'),
          _buildTile(
            icon: Icons.person_outline_rounded,
            title: 'アカウント情報',
            subtitle: profileAsync.whenOrNull(
              data: (p) => p?.email ?? '',
            ),
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('アプリ設定'),
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
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('サポート'),
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
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => _showLogoutDialog(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondary,
                side: const BorderSide(color: AppColors.secondary),
              ),
              child: const Text('ログアウト'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textPrimary),
        title: Text(title, style: AppTextStyles.bodyLarge),
        subtitle: subtitle != null
            ? Text(subtitle, style: AppTextStyles.bodySmall)
            : null,
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('ログアウト', style: AppTextStyles.headlineSmall),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'キャンセル',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authStateNotifierProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
