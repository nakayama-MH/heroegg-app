import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../providers/check_in_provider.dart';
import 'widgets/check_in_result_dialog.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  late final AnimationController _breatheController;
  late final Animation<double> _breatheAnimation;

  static final _uuidRegExp = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);
    await _controller.stop();

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
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          'QRコードをスキャン',
          style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          _buildOverlay(),
          if (_isProcessing) _buildProcessingIndicator(),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Center(
      child: Shimmer.fromColors(
        baseColor: Colors.white,
        highlightColor: AppColors.primary,
        child: Image.asset(
          'assets/images/logo_vertical.png',
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanSize = constraints.maxWidth * 0.7;
        final centerY = (constraints.maxHeight / 2) - 40;
        final centerX = constraints.maxWidth / 2;
        final top = centerY - scanSize / 2;

        return Stack(
          children: [
            // Vignette overlay with scan area cutout
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _VignetteOverlayPainter(
                scanRect: Rect.fromCenter(
                  center: Offset(centerX, centerY),
                  width: scanSize,
                  height: scanSize,
                ),
                borderRadius: 16,
              ),
            ),
            // Corner brackets with breathing animation
            AnimatedBuilder(
              animation: _breatheAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _ScanCornersPainter(
                    scanRect: Rect.fromCenter(
                      center: Offset(centerX, centerY),
                      width: scanSize,
                      height: scanSize,
                    ),
                    borderRadius: 16,
                    opacity: _breatheAnimation.value,
                  ),
                );
              },
            ),
            // Instruction text with pill background
            Positioned(
              left: 0,
              right: 0,
              top: top + scanSize + 60,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '施設のQRコードを枠内に合わせてください',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VignetteOverlayPainter extends CustomPainter {
  _VignetteOverlayPainter({
    required this.scanRect,
    required this.borderRadius,
  });

  final Rect scanRect;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final scanRRect =
        RRect.fromRectAndRadius(scanRect, Radius.circular(borderRadius));

    final cutoutPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      Path()..addRRect(scanRRect),
    );

    final gradient = RadialGradient(
      center: Alignment(
        (scanRect.center.dx / size.width) * 2 - 1,
        (scanRect.center.dy / size.height) * 2 - 1,
      ),
      radius: 1.2,
      colors: [
        Colors.black.withValues(alpha: 0.3),
        Colors.black.withValues(alpha: 0.75),
      ],
      stops: const [0.3, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(fullRect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(cutoutPath, paint);
  }

  @override
  bool shouldRepaint(_VignetteOverlayPainter oldDelegate) =>
      scanRect != oldDelegate.scanRect;
}

class _ScanCornersPainter extends CustomPainter {
  _ScanCornersPainter({
    required this.scanRect,
    required this.borderRadius,
    required this.opacity,
  });

  final Rect scanRect;
  final double borderRadius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: opacity)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const armLength = 28.0;
    final r = borderRadius.toDouble();
    final left = scanRect.left;
    final top = scanRect.top;
    final right = scanRect.right;
    final bottom = scanRect.bottom;

    // Top-left
    _drawCorner(canvas, paint, left, top, armLength, r, topLeft: true);
    // Top-right
    _drawCorner(canvas, paint, right, top, armLength, r, topRight: true);
    // Bottom-left
    _drawCorner(canvas, paint, left, bottom, armLength, r, bottomLeft: true);
    // Bottom-right
    _drawCorner(canvas, paint, right, bottom, armLength, r, bottomRight: true);
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double arm,
    double r, {
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    final path = Path();

    if (topLeft) {
      path.moveTo(x, y + arm);
      path.lineTo(x, y + r);
      path.quadraticBezierTo(x, y, x + r, y);
      path.lineTo(x + arm, y);
    } else if (topRight) {
      path.moveTo(x - arm, y);
      path.lineTo(x - r, y);
      path.quadraticBezierTo(x, y, x, y + r);
      path.lineTo(x, y + arm);
    } else if (bottomLeft) {
      path.moveTo(x, y - arm);
      path.lineTo(x, y - r);
      path.quadraticBezierTo(x, y, x + r, y);
      path.lineTo(x + arm, y);
    } else if (bottomRight) {
      path.moveTo(x - arm, y);
      path.lineTo(x - r, y);
      path.quadraticBezierTo(x, y, x, y - r);
      path.lineTo(x, y - arm);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScanCornersPainter oldDelegate) =>
      opacity != oldDelegate.opacity || scanRect != oldDelegate.scanRect;
}
