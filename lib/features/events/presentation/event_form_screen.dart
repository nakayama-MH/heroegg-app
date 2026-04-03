import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_view.dart';
import '../models/event_model.dart';
import '../providers/event_provider.dart';
import '../utils/quill_utils.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.eventId});

  final String? eventId;

  bool get isEditing => eventId != null;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  late QuillController _quillController;
  final FocusNode _quillFocusNode = FocusNode();

  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _eventTime = const TimeOfDay(hour: 19, minute: 0);
  String _status = 'active';
  bool _initialized = false;

  // 画像関連
  String? _imageUrl; // 既存 or アップロード後のURL
  Uint8List? _pickedImageBytes; // 選択されたファイルのバイト
  String? _pickedImageExt; // 拡張子
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _quillController.dispose();
    _quillFocusNode.dispose();
    super.dispose();
  }

  void _initFromEvent(Event event) {
    if (_initialized) return;
    _initialized = true;
    _titleController.text = event.title;
    _locationController.text = event.locationName;
    _imageUrl = event.imageUrl;
    _eventDate = event.eventDate;
    _eventTime = TimeOfDay.fromDateTime(event.eventDate);
    _status = event.status;

    _quillController.dispose();
    _quillController = controllerFromDescription(event.description);
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _eventTime.hour,
      _eventTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('ja'),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime,
    );
    if (picked != null) {
      setState(() => _eventTime = picked);
    }
  }

  Future<void> _pickImage() async {
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
              if (!kIsWeb)
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
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.split('.').last.toLowerCase();

    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExt = ext;
      _imageUrl = null; // ファイル選択時はURLをクリア
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExt = null;
      _imageUrl = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    String? finalImageUrl = _imageUrl;

    // 新しい画像が選択されていたらアップロード
    if (_pickedImageBytes != null && _pickedImageExt != null) {
      setState(() => _isUploadingImage = true);
      try {
        final repo = ref.read(eventRepositoryProvider);
        finalImageUrl =
            await repo.uploadEventImage(_pickedImageBytes!, _pickedImageExt!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('画像のアップロードに失敗しました: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isUploadingImage = false);
        return;
      }
      setState(() => _isUploadingImage = false);
    }

    final descriptionJson = descriptionFromController(_quillController);

    final event = Event(
      id: widget.eventId ?? '',
      title: _titleController.text.trim(),
      description: descriptionJson,
      eventDate: _combinedDateTime,
      locationName: _locationController.text.trim(),
      imageUrl: finalImageUrl,
      status: _status,
    );

    final notifier = ref.read(eventFormProvider.notifier);

    if (widget.isEditing) {
      await notifier.updateEvent(widget.eventId!, event);
    } else {
      await notifier.createEvent(event);
    }

    final formState = ref.read(eventFormProvider);
    if (formState.hasError && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存に失敗しました: ${formState.error}'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEditing ? 'イベントを更新しました' : 'イベントを作成しました'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(eventFormProvider);
    final isLoading = formState.isLoading || _isUploadingImage;
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'イベント編集' : 'イベント作成',
          style: AppTextStyles.headlineSmall,
        ),
      ),
      body: widget.isEditing
          ? ref.watch(eventDetailProvider(widget.eventId!)).when(
                data: (event) {
                  _initFromEvent(event);
                  return _buildForm(dateFormat, isLoading);
                },
                loading: () =>
                    const LoadingIndicator(message: 'イベントを取得中...'),
                error: (error, _) => ErrorView(
                  message: 'イベントの取得に失敗しました',
                  onRetry: () =>
                      ref.invalidate(eventDetailProvider(widget.eventId!)),
                ),
              )
          : _buildForm(dateFormat, isLoading),
    );
  }

  Widget _buildForm(DateFormat dateFormat, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タイトル
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration('タイトル', Icons.title),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // 日付選択
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration:
                    _inputDecoration('開催日', Icons.calendar_today_outlined),
                child: Text(
                  dateFormat.format(_eventDate),
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 時間選択
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration('開催時間', Icons.access_time),
                child: Text(
                  _eventTime.format(context),
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 場所
            TextFormField(
              controller: _locationController,
              decoration: _inputDecoration('場所', Icons.location_on_outlined),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // ─── サムネイル画像 ───
            Text('サムネイル画像', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            _buildImagePicker(),
            const SizedBox(height: 16),

            // ステータス
            DropdownButtonFormField<String>(
              value: _status,
              decoration: _inputDecoration('ステータス', Icons.flag_outlined),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('公開中')),
                DropdownMenuItem(value: 'completed', child: Text('終了')),
                DropdownMenuItem(value: 'cancelled', child: Text('キャンセル')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _status = v);
              },
            ),
            const SizedBox(height: 16),

            // 説明（リッチエディタ）
            Text('説明', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),

            // ツールバー
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border.all(color: AppColors.border),
              ),
              child: QuillSimpleToolbar(
                controller: _quillController,
                config: QuillSimpleToolbarConfig(
                  showAlignmentButtons: false,
                  showBackgroundColorButton: false,
                  showCenterAlignment: false,
                  showCodeBlock: false,
                  showDirection: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showIndent: false,
                  showInlineCode: false,
                  showJustifyAlignment: false,
                  showLeftAlignment: false,
                  showRightAlignment: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showQuote: false,
                  showStrikeThrough: false,
                  showColorButton: false,
                  showClearFormat: true,
                  showUndo: true,
                  showRedo: true,
                  multiRowsDisplay: false,
                ),
              ),
            ),

            // エディタ本体
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border.all(color: AppColors.border),
              ),
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _quillFocusNode,
                config: QuillEditorConfig(
                  placeholder: 'イベントの説明を入力...',
                  padding: const EdgeInsets.all(12),
                  expands: true,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 保存ボタン
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('保存中...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      )
                    : Text(
                        widget.isEditing ? '更新する' : '作成する',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 画像選択ウィジェット
  Widget _buildImagePicker() {
    final hasPickedFile = _pickedImageBytes != null;
    final hasExistingUrl = _imageUrl != null && _imageUrl!.isNotEmpty;

    // プレビュー表示
    if (hasPickedFile || hasExistingUrl) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: hasPickedFile
                  ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.surfaceDim,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surfaceDim,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              size: 32, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
            ),
            // 操作ボタン
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _ImageActionButton(
                    icon: Icons.edit_rounded,
                    onTap: _pickImage,
                  ),
                  const SizedBox(width: 6),
                  _ImageActionButton(
                    icon: Icons.close_rounded,
                    onTap: _removeImage,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 未選択時の選択エリア
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              '画像をアップロード',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'タップして画像を選択',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color ?? Colors.white),
      ),
    );
  }
}
