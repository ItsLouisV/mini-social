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
  
  // Các Controller độc lập quản lý mượt mà luồng Animation
  late AnimationController _zoomAnimationController;
  late AnimationController _dismissAnimationController;
  
  Animation<Matrix4>? _zoomAnimation;
  Animation<Offset>? _dismissAnimation;

  // Cập nhật giá trị tương tác qua ValueNotifier để tránh rebuild toàn bộ cây widget
  final ValueNotifier<Offset> _dragOffset = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);

  // Quản lý vuốt chạm nâng cao (Bypass Gesture Arena Latency)
  int? _activePointerId;
  Offset _dragStartPoint = Offset.zero;
  bool _pointerDownInsideImage = false;
  bool _isZoomed = false;

  // Lưu trữ vị trí và tỉ lệ kéo cuối cùng để truyền vào Hero Flight Shuttle
  Offset _lastDragOffset = Offset.zero;
  double _lastDragScale = 1.0;

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
    _zoomAnimationController.addListener(_applyZoomAnimation);
    _dismissAnimationController.addListener(_applyDismissAnimation);
  }

  void _handleZoomChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    // Ngưỡng xác định xem ảnh có đang phóng to hay không
    final zoomed = scale > 1.02;
    if (zoomed != _isZoomed) {
      setState(() { _isZoomed = zoomed; });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleZoomChanged);
    _zoomAnimationController.removeListener(_applyZoomAnimation);
    _dismissAnimationController.removeListener(_applyDismissAnimation);
    
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    _dismissAnimationController.dispose();
    _dragOffset.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  // ── 1. Đúp chạm phóng to / thu nhỏ mượt mà chuẩn vị trí chạm ngón tay ───────────
  void _onDoubleTapDown(TapDownDetails details) {
    if (_zoomAnimationController.isAnimating) return;

    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.5 ? 1.0 : 3.0;

    final Matrix4 endMatrix;
    if (targetScale == 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      // Lấy tọa độ chạm so với toàn bộ màn hình (viewport của InteractiveViewer) thay vì tọa độ ảnh
      final pos = renderBox.globalToLocal(details.globalPosition);
      final translation = Matrix4.translationValues(
        -pos.dx * (targetScale - 1),
        -pos.dy * (targetScale - 1),
        0.0,
      );
      final scaling = Matrix4.diagonal3Values(targetScale, targetScale, 1.0);
      endMatrix = translation * scaling;
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
  }

  void _applyZoomAnimation() {
    if (_zoomAnimation != null) {
      _transformationController.value = _zoomAnimation!.value;
    }
  }

  // ── 2. Xử lý đàn hồi khi pinch-zoom quá nhỏ ──────────────────────────────────────
  void _handleInteractionEnd(ScaleEndDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    // Elastic Snapback: Đưa ảnh về kích thước chuẩn 1.0 nếu pinch nhỏ quá mức
    if (currentScale < 1.0) {
      if (_zoomAnimationController.isAnimating) return;

      _zoomAnimation = Matrix4Tween(
        begin: _transformationController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutBack, // Hiệu ứng đàn hồi mô phỏng vật lý iOS
      ));

      _zoomAnimationController.forward(from: 0.0).then((_) {
        _transformationController.value = Matrix4.identity();
      });
    }
  }

  void _applyDismissAnimation() {
    if (_dismissAnimation != null) {
      _dragOffset.value = _dismissAnimation!.value;
    }
  }

  // ── 3. Quản lý tương tác vuốt dọc 2D để đóng chuẩn iOS ───────────────────────────
  void _handlePointerDown(PointerDownEvent event) {
    if (_isZoomed) return;

    // Ngăn chặn đa điểm chạm (pinch) xung đột với hành động vuốt đóng
    if (_activePointerId != null) {
      if (_isDragging.value) {
        _isDragging.value = false;
        _dismissAnimation = Tween<Offset>(
          begin: _dragOffset.value,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _dismissAnimationController,
          curve: Curves.easeOutBack,
        ));
        _dismissAnimationController.forward(from: 0.0);
      }
      _pointerDownInsideImage = false;
      return;
    }

    _activePointerId = event.pointer;
    _pointerDownInsideImage = true;
    _dragStartPoint = event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId || !_pointerDownInsideImage || _isZoomed) return;

    final delta = event.position - _dragStartPoint;

    // Nhận diện kéo: Ưu tiên kéo dọc (dy) lớn hơn kéo ngang (dx) để tránh xung đột
    if (!_isDragging.value) {
      if (delta.dy.abs() > 10 && delta.dy.abs() > delta.dx.abs()) {
        _isDragging.value = true;
        // Triệt tiêu khoảng lệch ban đầu để tránh bị giật hình khi bắt đầu kéo
        _dragStartPoint = event.position - Offset(delta.dx, delta.dy.sign * 10);
      }
    }

    if (_isDragging.value) {
      final currentDelta = event.position - _dragStartPoint;
      double dy = currentDelta.dy;
      // Damping (giảm chấn) khi kéo lên trên giống hệt iOS
      if (dy < 0) {
        dy = dy * 0.65;
      }
      _dragOffset.value = Offset(currentDelta.dx, dy);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) return;
    _activePointerId = null;

    if (!_isDragging.value) {
      _pointerDownInsideImage = false;
      return;
    }

    _pointerDownInsideImage = false;
    _isDragging.value = false;

    final finalOffset = _dragOffset.value;
    final size = MediaQuery.of(context).size;

    // Nếu khoảng cách kéo theo trục dọc đủ lớn (> 100px) -> Tiến hành đóng
    if (finalOffset.dy.abs() > 100) {
      _lastDragOffset = finalOffset;
      _lastDragScale = (1.0 - (finalOffset.dy.abs() / (size.height * 2.5))).clamp(0.75, 1.0);
      Navigator.pop(context);
    } else {
      // Trả ảnh về vị trí tâm ban đầu với hiệu ứng Spring mượt mà
      _dismissAnimation = Tween<Offset>(
        begin: finalOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _dismissAnimationController,
        curve: Curves.easeOutBack,
      ));
      _dismissAnimationController.forward(from: 0.0);
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
          child: ValueListenableBuilder<Offset>(
            valueListenable: _dragOffset,
            builder: (context, dragOffset, child) {
              final dragDistance = dragOffset.dy.abs();
              // Tính toán độ mờ nền đen dựa trên biên độ kéo dọc
              final opacity = (1.0 - (dragDistance / (size.height * 0.55))).clamp(0.0, 1.0);
              // Tỉ lệ scale thu nhỏ ảnh khi kéo (chuẩn Instagram/iOS)
              final scale = (1.0 - (dragDistance / (size.height * 2.5))).clamp(0.75, 1.0);

              return Container(
                color: Colors.black.withValues(alpha: opacity),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Tap vào vùng trống ngoài ảnh để đóng nhanh
                    GestureDetector(
                      onTap: () {
                        if (!_isZoomed) Navigator.pop(context);
                      },
                      child: Transform.translate(
                        offset: dragOffset,
                        child: Transform.scale(
                          scale: scale,
                          child: InteractiveViewer(
                            transformationController: _transformationController,
                            clipBehavior: Clip.none,
                            boundaryMargin: const EdgeInsets.all(30),
                            minScale: 0.2,
                            maxScale: 8.0,
                            panEnabled: _isZoomed,
                            scaleEnabled: true,
                            onInteractionEnd: _handleInteractionEnd,
                            child: Center(
                              child: Hero(
                                tag: widget.imageUrl,
                                createRectTween: (begin, end) {
                                  // Chuyển động bay thẳng tuyến tính thay vì bay cong (Arc) giúp ảnh bay tự nhiên hơn
                                  return RectTween(begin: begin, end: end);
                                },
                                flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                  final Hero fromHero = fromHeroContext.widget as Hero;
                                  final Hero toHero = toHeroContext.widget as Hero;

                                  // Xác định component nguồn và đích dựa trên hướng bay (Push/Pop)
                                  final thumbnailChild = flightDirection == HeroFlightDirection.push
                                      ? fromHero.child
                                      : toHero.child;
                                  final fullscreenChild = flightDirection == HeroFlightDirection.push
                                      ? toHero.child
                                      : fromHero.child;

                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      final t = animation.value;

                                      // Nội suy vị trí bay từ tọa độ kéo tay cuối cùng về vị trí ảnh gốc
                                      final offset = (flightDirection == HeroFlightDirection.pop)
                                          ? Offset.lerp(Offset.zero, _lastDragOffset, t)!
                                          : Offset.zero;

                                      final scaleVal = (flightDirection == HeroFlightDirection.pop)
                                          ? 1.0 + (_lastDragScale - 1.0) * t
                                          : 1.0;

                                      return Transform.translate(
                                        offset: offset,
                                        child: Transform.scale(
                                          scale: scaleVal,
                                          child: Stack(
                                            fit: StackFit.passthrough,
                                            children: [
                                              // Cross-fade mượt mà giữa ảnh thumbnail và ảnh phóng to để triệt tiêu hiện tượng vỡ tỉ lệ ảnh
                                              Opacity(
                                                opacity: (1.0 - t).clamp(0.0, 1.0),
                                                child: thumbnailChild,
                                              ),
                                              Opacity(
                                                opacity: t.clamp(0.0, 1.0),
                                                child: fullscreenChild,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: GestureDetector(
                                  onTap: () {}, // Ngăn chặn sự kiện tap lan truyền ra GestureDetector ngoài gây đóng ảnh
                                  onDoubleTapDown: _onDoubleTapDown,
                                  onDoubleTap: () {}, // Giữ block trống để kích hoạt Double Tap Down độc lập
                                  child: _buildImage(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Nút đóng (X) thiết kế tinh xảo, ẩn đi khi bắt đầu kéo ảnh
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
            // Triệt tiêu thời gian chuyển đổi của CachedNetworkImage để tránh chớp nháy ảnh khi bắt đầu bay Hero
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
            errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey, size: 50),
          );
  }
}
