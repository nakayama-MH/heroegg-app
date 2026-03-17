import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../models/profile_model.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  Profile? _currentProfile;

  void _populateFields(Profile profile) {
    _currentProfile = profile;
    _nameController.text = profile.displayName ?? '';
    _phoneController.text = profile.phone ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentProfile == null) return;

    final updated = _currentProfile!.copyWith(
      displayName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    await ref.read(profileUpdateProvider.notifier).updateProfile(updated);

    if (mounted) {
      final state = ref.read(profileUpdateProvider);
      state.when(
        data: (_) {
          setState(() => _isEditing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プロフィールを更新しました'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        error: (error, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新に失敗しました: $error'),
              backgroundColor: AppColors.error,
            ),
          );
        },
        loading: () {},
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final updateState = ref.watch(profileUpdateProvider);
    final isUpdating = updateState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text('プロフィール', style: AppTextStyles.headlineSmall),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _isEditing = false;
                if (_currentProfile != null) {
                  _populateFields(_currentProfile!);
                }
              }),
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const ErrorView(message: 'プロフィールが見つかりませんでした');
          }

          if (_currentProfile == null) {
            _populateFields(profile);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      (profile.displayName ?? profile.email)
                          .substring(0, 1)
                          .toUpperCase(),
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (profile.accountType != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile.accountType!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildField(
                    label: 'メールアドレス',
                    value: profile.email,
                    icon: Icons.mail_outline_rounded,
                    enabled: false,
                  ),
                  const SizedBox(height: 16),
                  _isEditing
                      ? TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: '表示名',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => Validators.required(v, '表示名'),
                        )
                      : _buildField(
                          label: '表示名',
                          value: profile.displayName ?? '未設定',
                          icon: Icons.person_outline_rounded,
                        ),
                  const SizedBox(height: 16),
                  _isEditing
                      ? TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '電話番号',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: Validators.phone,
                        )
                      : _buildField(
                          label: '電話番号',
                          value: profile.phone ?? '未設定',
                          icon: Icons.phone_outlined,
                        ),
                  if (profile.memberRank != null) ...[
                    const SizedBox(height: 16),
                    _buildField(
                      label: '会員ランク',
                      value: profile.memberRank!,
                      icon: Icons.star_outline_rounded,
                    ),
                  ],
                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isUpdating ? null : _saveProfile,
                        child: isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('保存する'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          message: 'プロフィールの取得に失敗しました',
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required IconData icon,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
