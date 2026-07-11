import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  /// Phương thức mở Viewer với hiệu ứng FadeTransition nền mượt mà
  static void open(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        maintainState: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) => FullScreenImageViewer(imageUrl: imageUrl),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with TickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  
  // Các Controller độc lập để quản lý mượt mà luồng Animation
  late AnimationController _zoomAnimationController;
  late AnimationController _dismissAnimationController;
  
  Animation<Matrix4>? _zoomAnimation;
  Animation<double>? _dismissAnimation;

  // Cập nhật giá trị đồ họa qua ValueNotifier để bypass việc re-build toàn bộ UI
  final ValueNotifier<double> _dragY = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);

  double _dragStartY = 0.0;
  bool _isZoomed = false;
  bool _pointerDownInsideImage = false;

  bool get _isLocalPath =>
      !widget.imageUrl.startsWith('http') && !widget.imageUrl.startsWith('blob');

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _dismissAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _transformationController.addListener(_handleZoomChanged);
  }

  void _handleZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    // Đặt ngưỡng > 1.02 để xác định ảnh có đang bị phóng to hay không
    final zoomed = scale > 1.02;
    if (zoomed != _isZoomed) {
      setState(() { _isZoomed = zoomed; });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleZoomChanged);
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    _dismissAnimationController.dispose();
    _dragY.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  // ── 1. Đúp chạm phóng to / thu nhỏ chuẩn xác theo vị trí ngón tay ─────────────
  void _onDoubleTapDown(TapDownDetails details) {
    if (_zoomAnimationController.isAnimating) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.5 ? 1.0 : 3.0;

    final Matrix4 endMatrix;
    if (targetScale == 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final pos = details.localPosition;
      endMatrix = Matrix4.identity()
        ..translate(-pos.dx * (targetScale - 1), -pos.dy * (targetScale - 1))
        ..scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.fastOutSlowIn,
    ));

    _zoomAnimationController.forward(from: 0.0).then((_) {
      _transformationController.value = endMatrix;
    });
    
    _zoomAnimationController.addListener(_applyZoomAnimation);
  }

  void _applyZoomAnimation() {
    if (_zoomAnimation != null) {
      _transformationController.value = _zoomAnimation!.value;
    }
  }

  // ── 2. Xử lý tương tác thu phóng bằng hai ngón tay (InteractiveViewer) ────────
  void _handleInteractionEnd(ScaleEndDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    // Hiệu ứng Elastic Snapback: Bật ảnh về kích thước gốc 1.0 nếu bị bóp nhỏ quá mức
    if (currentScale < 1.0) {
      if (_zoomAnimationController.isAnimating) return;

      _zoomAnimation = Matrix4Tween(
        begin: _transformationController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutBack, // Đường cong mô phỏng lực đàn hồi vật lý
      ));

      _zoomAnimationController.forward(from: 0.0).then((_) {
        _transformationController.value = Matrix4.identity();
      });

      _zoomAnimationController.addListener(_applyZoomAnimation);
    }
  }

  // ── 3. Hệ thống xử lý vuốt dọc để đóng tốc độ cao (Bypass Gesture Latency) ────
  void _handlePointerDown(PointerDownEvent event) {
    if (_isZoomed) return;
    _pointerDownInsideImage = true;
    _dragStartY = event.position.dy;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointerDownInsideImage || _isZoomed) return;
    
    final deltaY = event.position.dy - _dragStartY;
    
    // Ngưỡng lọc nhiễu (Slop): Tránh nhận diện nhầm khi chỉ chạm tay nhẹ
    if (!_isDragging.value && deltaY.abs() > 12) {
      _isDragging.value = true;
    }

    if (_isDragging.value) {
      // Công thức cản lực (Damping) của iOS khi kéo ngược lên hoặc kéo quá sâu
      if (deltaY > 0) {
        _dragY.value = deltaY;
      } else {
        _dragY.value = deltaY * 0.65; 
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_isDragging.value) {
      _pointerDownInsideImage = false;
      return;
    }

    _pointerDownInsideImage = false;
    _isDragging.value = false;

    // Quãng đường vuốt đủ lớn (> 140px) -> Đóng màn hình
    if (_dragY.value.abs() > 140) {
      Navigator.pop(context);
    } else {
      // Trả ảnh về tâm đối xứng bằng hiệu ứng đàn hồi Spring mượt mà
      _dismissAnimation = Tween<double>(begin: _dragY.value, end: 0.0).animate(
        CurvedAnimation(parent: _dismissAnimationController, curve: Curves.easeOutBack),
      );
      _dismissAnimationController.forward(from: 0.0);
      _dismissAnimationController.addListener(_applyDismissAnimation);
    }
  }

  void _applyDismissAnimation() {
    if (_dismissAnimation != null) {
      _dragY.value = _dismissAnimation!.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          child: ValueListenableBuilder<double>(
            valueListenable: _dragY,
            builder: (context, dragY, child) {
              // Nội suy độ mờ của nền dựa trên biên độ kéo dọc
              final opacity = (1.0 - (dragY.abs() / (size.height * 0.55))).clamp(0.0, 1.0);

              return Container(
                color: Colors.black.withValues(alpha: opacity),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Tap vào vùng trống bao quanh để đóng nhanh
                    GestureDetector(
                      onTap: () {
                        if (!_isZoomed) Navigator.pop(context);
                      },
                      child: Transform.translate(
                        offset: Offset(0, dragY),
                        // Hiệu ứng Scale Down thu nhỏ nhẹ ảnh khi kéo xuống (Chuẩn Instagram/Telegram)
                        child: Transform.scale(
                          scale: (1.0 - (dragY.abs() / (size.height * 2.8))).clamp(0.85, 1.0),
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            clipBehavior: Clip.none,
                            boundaryMargin: const EdgeInsets.all(30),
                            minScale: 0.2, // Cho phép bóp nhỏ hơn 1.0 để kích hoạt Elastic Snapback
                            maxScale: 8.0,
                            panEnabled: _isZoomed,
                            scaleEnabled: true,
                            onInteractionEnd: _handleInteractionEnd,
                            child: Center(
                              child: Hero(
                                tag: widget.imageUrl,
                                // Khắc phục triệt để lỗi giật khung hình / méo ảnh khi Hero chuyển trạng thái bay
                                flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                  final Hero toHero = toHeroContext.widget as Hero;
                                  return SizeChangedLayoutNotifier(
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: toHero.child,
                                    ),
                                  );
                                },
                                child: GestureDetector(
                                  onDoubleTapDown: _onDoubleTapDown,
                                  onDoubleTap: () {}, // Cần giữ block trống này để kích hoạt luồng onDoubleTapDown riêng
                                  child: _buildImage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Nút Đóng thiết kế cao cấp ứng dụng lớn
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 16,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isDragging,
                        builder: (context, isDragging, _) {
                          return AnimatedOpacity(
                            opacity: isDragging ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black38,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(8),
                              ),
                              icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return _isLocalPath && !kIsWeb
        ? Image.file(io.File(widget.imageUrl), fit: BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            // Ép thời gian chuyển đổi ảnh bằng 0 để triệt tiêu hiện tượng nháy ảnh khi bắt đầu bay Hero
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey, size: 50),
          );
  }
}