import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/check_in_provider.dart';
import 'widgets/check_in_result_dialog.dart';

class QrScannerWebScreen extends ConsumerStatefulWidget {
  const QrScannerWebScreen({super.key});

  @override
  ConsumerState<QrScannerWebScreen> createState() =>
      _QrScannerWebScreenState();
}

class _QrScannerWebScreenState extends ConsumerState<QrScannerWebScreen> {
  final _manualController = TextEditingController();
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _showManualInput = false;
  bool _cameraFailed = false;

  static final _uuidRegExp = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _initCamera() {
    _scannerController = MobileScannerController();
    _scannerController!.start().catchError((_) {
      if (mounted) {
        setState(() => _cameraFailed = true);
      }
    });
  }

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    _scannerController?.stop();

    if (!_uuidRegExp.hasMatch(code)) {
      if (mounted) {
        await CheckInResultDialog.showError(
          context,
          message: '無効なQRコードです',
        );
        _resetScanner();
      }
      return;
    }

    await _performCheckIn(code);
  }

  Future<void> _submitManual() async {
    final code = _manualController.text.trim();
    if (code.isEmpty) return;

    if (!_uuidRegExp.hasMatch(code)) {
      await CheckInResultDialog.showError(
        context,
        message: '無効な施設IDです',
      );
      return;
    }

    setState(() => _isProcessing = true);
    await _performCheckIn(code);
  }

  Future<void> _performCheckIn(String code) async {
    try {
      final checkIn = await ref
          .read(checkInActionProvider.notifier)
          .performCheckIn(code);

      if (mounted) {
        await CheckInResultDialog.showSuccess(
          context,
          facilityName: checkIn.facilityName ?? '施設',
        );
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        await CheckInResultDialog.showError(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
        );
        _resetScanner();
      }
    }
  }

  void _resetScanner() {
    setState(() => _isProcessing = false);
    _scannerController?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRチェックイン'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _showManualInput = !_showManualInput),
            icon: Icon(_showManualInput ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded, size: 18),
            label: Text(_showManualInput ? 'スキャン' : 'ID入力'),
          ),
        ],
      ),
      body: _showManualInput || _cameraFailed
          ? _buildManualInput()
          : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        if (_scannerController != null)
          MobileScanner(
            controller: _scannerController!,
            onDetect: _onDetect,
          ),
        // Overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Instruction
        Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '施設のQRコードを枠内に合わせてください',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildManualInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Icon(
            _cameraFailed ? Icons.videocam_off_rounded : Icons.keyboard_rounded,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            _cameraFailed
                ? 'カメラを利用できません\n施設IDを入力してチェックインできます'
                : '施設IDを直接入力してチェックイン',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('施設IDで直接チェックイン', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'スタッフから受け取った施設IDを入力してください',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _manualController,
                  decoration: const InputDecoration(hintText: '施設ID（UUID）'),
                  onSubmitted: (_) => _submitManual(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isProcessing ? null : _submitManual,
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('チェックイン'),
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
