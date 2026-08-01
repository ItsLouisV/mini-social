import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../utils/qr_image_decoder.dart';
import '../widgets/qr_profile_bottom_sheet.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late AnimationController _animController;
  late Animation<double> _zoomAnimation;

  bool _isProcessing = false;
  bool _isDetected = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Breathing zoom animation controller (Idle state)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _zoomAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    _processQrCode(rawValue.trim());
  }

  void _processQrCode(String qrData) async {
    setState(() => _isProcessing = true);

    String? extractedUserId;

    // Parse payload: viora://profile/<userId> or https://viora.app/profile/<userId> or raw UUID
    if (qrData.startsWith('viora://profile/')) {
      extractedUserId = qrData.replaceFirst('viora://profile/', '').trim();
    } else if (qrData.contains('/profile/')) {
      final parts = qrData.split('/profile/');
      if (parts.length > 1) {
        extractedUserId = parts.last.split('?').first.split('/').first.trim();
      }
    } else if (RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(qrData)) {
      extractedUserId = qrData;
    }

    final currentUserId = ref.read(currentUserIdProvider);

    if (extractedUserId == null || extractedUserId.isEmpty) {
      _showToast('Mã QR không hợp lệ hoặc không thuộc hệ thống Viora');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Trigger visual snap-lock & checkmark verification animation
    if (mounted) {
      setState(() => _isDetected = true);
    }

    await Future.delayed(const Duration(milliseconds: 450));

    // Nếu quét mã QR của chính mình
    if (currentUserId != null && extractedUserId == currentUserId) {
      if (mounted) {
        context.pushReplacement('/my-qr');
      }
      return;
    }

    // Nếu mã hợp lệ của bạn bè
    if (mounted) {
      final targetId = extractedUserId;
      context.pop(); // Đóng màn hình quét
      QrProfileBottomSheet.show(context, targetId);
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    if (_isProcessing) return;

    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isProcessing = true);

      String? qrResult;

      if (kIsWeb) {
        // Web Platform: Use native Web BarcodeDetector
        qrResult = await decodeQrFromWebImage(image);
      } else {
        // Mobile / Native Platform: Use MobileScanner analyzeImage
        try {
          final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            qrResult = capture.barcodes.first.rawValue;
          }
        } catch (e) {
          debugPrint('analyzeImage native error: $e');
        }
      }

      if (qrResult != null && qrResult.trim().isNotEmpty) {
        _processQrCode(qrResult.trim());
      } else {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        _showToast('Không tìm thấy mã QR hợp lệ trong ảnh');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      _showToast('Không thể phân tích ảnh: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Mobile Scanner View
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // 2. Scanner Dark Overlay & Gentle Breathing / Lock Check Animation Frame
          _buildScannerOverlay(context),

          // 3. Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
                    ),
                  ),

                  const Text(
                    'Quét mã QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Torch Flashlight Toggle
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, state, child) {
                      final torchState = state.torchState;
                      final isTorchOn = torchState == TorchState.on;

                      return IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isTorchOn ? Colors.amber : Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isTorchOn ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Controls Bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    _isDetected
                        ? 'Đã xác nhận mã QR! Đang kết nối...'
                        : 'Di chuyển ống kính đến mã QR của bạn bè',
                    style: TextStyle(
                      color: _isDetected ? const Color(0xFF10B981) : Colors.white70,
                      fontSize: 13,
                      fontWeight: _isDetected ? FontWeight.bold : FontWeight.normal,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Select from Gallery Button
                      ElevatedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(CupertinoIcons.photo, color: Colors.white, size: 18),
                        label: const Text(
                          'Chọn từ thư viện',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Switch Camera Front/Back Button
                      IconButton(
                        onPressed: () => _controller.switchCamera(),
                        icon: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(CupertinoIcons.camera_rotate, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final baseScanAreaSize = MediaQuery.of(context).size.width * 0.74;
    final activeColor = _isDetected ? const Color(0xFF10B981) : const Color(0xFF38BDF8);

    return AnimatedBuilder(
      animation: _zoomAnimation,
      builder: (context, child) {
        final currentScale = _isDetected ? 0.55 : _zoomAnimation.value;
        final currentSize = baseScanAreaSize * currentScale;

        return Stack(
          children: [
            // Outer dark vignette mask with synchronized tight hole cut-out
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.65),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: _isDetected ? 350 : 0),
                      curve: Curves.easeOutBack,
                      width: currentSize,
                      height: currentSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_isDetected ? 14 : 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Centered Scanner Box: Snaps TIGHTLY around QR code on detection
            Align(
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: Duration(milliseconds: _isDetected ? 350 : 0),
                curve: Curves.easeOutBack,
                width: currentSize,
                height: currentSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Futuristic Corner Brackets (Cyan idle, Emerald green detected)
                    CustomPaint(
                      size: Size(currentSize, currentSize),
                      painter: _ScannerCornerPainter(
                        color: activeColor,
                        cornerLength: _isDetected ? 26 : 42,
                        strokeWidth: _isDetected ? 4.0 : 4.5,
                        borderRadius: _isDetected ? 14 : 24,
                      ),
                    ),

                    // Verification Checkmark Seal (Shown when QR code is detected)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _isDetected ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 350),
                        scale: _isDetected ? 1.0 : 0.3,
                        curve: Curves.elasticOut,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            border: Border.all(color: const Color(0xFF10B981), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                blurRadius: 20,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            color: Color(0xFF10B981),
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter for Futuristic Neon L-shaped Corner Brackets
// ─────────────────────────────────────────────────────────────────────────────
class _ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double borderRadius;

  _ScannerCornerPainter({
    required this.color,
    this.cornerLength = 42.0,
    this.strokeWidth = 4.5,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);

    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final l = cornerLength;

    // Top-Left corner
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(l, 0);

    // Top-Right corner
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, l);

    // Bottom-Left corner
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(l, h);

    // Bottom-Right corner
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - l);

    canvas.drawPath(pathTL, paint);
    canvas.drawPath(pathTR, paint);
    canvas.drawPath(pathBL, paint);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) =>
      oldDelegate.color != color;
}
