import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _isUploadingAvatar = false;
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
        title: const Text('プロフィール'),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('編集'),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _isEditing = false;
                if (_currentProfile != null) {
                  _populateFields(_currentProfile!);
                }
              }),
              child: Text(
                'キャンセル',
                style: TextStyle(color: AppColors.textSecondary),
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // アバター
                  GestureDetector(
                    onTap: _isEditing ? () => _pickAvatar(ref) : null,
                    child: Stack(
                      children: [
                        _buildAvatar(profile),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.surface, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (_isUploadingAvatar)
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (profile.accountType != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        profile.accountType!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // 基本情報グループ
                  _buildGroup([
                    if (_isEditing)
                      _buildEditableRow(
                        controller: _nameController,
                        label: '表示名',
                        validator: (v) => Validators.required(v, '表示名'),
                      )
                    else
                      _buildRow('表示名', profile.displayName ?? '未設定'),
                    _buildRow('メールアドレス', profile.email),
                    _buildRow('性別', profile.genderLabel),
                    _buildRow('地域', profile.region ?? '未設定'),
                    _buildRow('生年月日', profile.birthDateText),
                    if (_isEditing)
                      _buildEditableRow(
                        controller: _phoneController,
                        label: '電話番号',
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                        isLast: true,
                      )
                    else
                      _buildRow('電話番号', profile.phone ?? '未設定', isLast: true),
                  ]),

                  if (profile.memberRank != null) ...[
                    const SizedBox(height: 20),
                    _buildGroup([
                      _buildRow('会員ランク', profile.memberRank!, isLast: true),
                    ]),
                  ],

                  const SizedBox(height: 20),

                  // チェックイン履歴リンク
                  _buildGroup([
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/checkin-history'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded,
                                  size: 20, color: AppColors.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('チェックイン履歴',
                                    style: AppTextStyles.bodyMedium),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  size: 20, color: AppColors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ]),

                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
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

                  const SizedBox(height: 40),
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

  Widget _buildRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
      ],
    );
  }

  Widget _buildEditableRow({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
      ],
    );
  }

  Widget _buildAvatar(Profile profile) {
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      return Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: profile.avatarUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: AppColors.surfaceDim,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _buildInitialAvatar(profile),
        ),
      );
    }
    return _buildInitialAvatar(profile);
  }

  Widget _buildInitialAvatar(Profile profile) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        (profile.displayName ?? profile.email).substring(0, 1).toUpperCase(),
        style: AppTextStyles.headlineLarge.copyWith(
          color: AppColors.textSecondary,
          fontSize: 32,
        ),
      ),
    );
  }

  Future<void> _pickAvatar(WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('ライブラリから選択'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref
          .read(avatarUploadProvider.notifier)
          .upload(File(picked.path));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィール画像を更新しました'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像のアップロードに失敗しました: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }
}
