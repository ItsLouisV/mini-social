import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class GalleryScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const GalleryScreen({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  /// Mở Gallery với hiệu ứng FadeTransition nền trong suốt mượt mà
  static void open(BuildContext context, {required List<String> imageUrls, int initialIndex = 0}) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        maintainState: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, _, __) => GalleryScreen(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with TickerProviderStateMixin {
  late int currentIndex;
  late PageController _pageController;

  // Controllers để quản lý hiệu ứng vuốt đóng
  late AnimationController _dismissAnimationController;
  Animation<Offset>? _dismissAnimation;

  // Quản lý tọa độ tương tác
  final ValueNotifier<Offset> _dragOffset = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);

  int? _activePointerId;
  Offset _dragStartPoint = Offset.zero;
  bool _pointerDownInsideImage = false;
  bool _isZoomed = false;

  // Tọa độ kéo cuối cùng để truyền vào Hero Flight Shuttle
  Offset _lastDragOffset = Offset.zero;
  double _lastDragScale = 1.0;

  late PhotoViewScaleStateController _scaleStateController;
  StreamSubscription<PhotoViewScaleState>? _scaleStateSubscription;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _dismissAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _dismissAnimationController.addListener(_applyDismissAnimation);

    _scaleStateController = PhotoViewScaleStateController();
    _scaleStateSubscription = _scaleStateController.outputScaleStateStream.listen(_handleScaleStateChanged);
  }

  void _handleScaleStateChanged(PhotoViewScaleState state) {
    final zoomed = state != PhotoViewScaleState.initial;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  void _applyDismissAnimation() {
    if (_dismissAnimation != null) {
      _dragOffset.value = _dismissAnimation!.value;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dismissAnimationController.removeListener(_applyDismissAnimation);
    _dismissAnimationController.dispose();
    _scaleStateSubscription?.cancel();
    _scaleStateController.dispose();
    _dragOffset.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  // ── Xử lý cử chỉ vuốt 2D đóng tương tự iOS ───────────────────────────
  void _handlePointerDown(PointerDownEvent event) {
    if (_isZoomed) return;

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

    // Chỉ nhận diện vuốt dọc để đóng khi delta dọc lớn hơn ngang
    if (!_isDragging.value) {
      if (delta.dy.abs() > 10 && delta.dy.abs() > delta.dx.abs()) {
        _isDragging.value = true;
        _dragStartPoint = event.position - Offset(delta.dx, delta.dy.sign * 10);
      }
    }

    if (_isDragging.value) {
      final currentDelta = event.position - _dragStartPoint;
      double dy = currentDelta.dy;
      if (dy < 0) {
        dy = dy * 0.65; // Giảm lực cản khi kéo lên trên
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

    // Khoảng cách kéo dọc đủ lớn (> 100px) -> tiến hành đóng
    if (finalOffset.dy.abs() > 100) {
      _lastDragOffset = finalOffset;
      _lastDragScale = (1.0 - (finalOffset.dy.abs() / (size.height * 2.5))).clamp(0.75, 1.0);
      Navigator.pop(context);
    } else {
      // Đưa ảnh về tâm mượt mà với hiệu ứng lò xo
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
      body: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        child: ValueListenableBuilder<Offset>(
          valueListenable: _dragOffset,
          builder: (context, dragOffset, child) {
            final dragDistance = dragOffset.dy.abs();
            final opacity = (1.0 - (dragDistance / (size.height * 0.55))).clamp(0.0, 1.0);
            final scale = (1.0 - (dragDistance / (size.height * 2.5))).clamp(0.75, 1.0);

            return Container(
              color: Colors.black.withValues(alpha: opacity),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Transform.translate(
                    offset: dragOffset,
                    child: Transform.scale(
                      scale: scale,
                      child: PhotoViewGallery.builder(
                        scrollPhysics: const BouncingScrollPhysics(),
                        builder: (BuildContext context, int index) {
                          return PhotoViewGalleryPageOptions(
                            imageProvider: CachedNetworkImageProvider(widget.imageUrls[index]),
                            initialScale: PhotoViewComputedScale.contained,
                            minScale: PhotoViewComputedScale.contained * 0.8,
                            maxScale: PhotoViewComputedScale.covered * 2,
                            heroAttributes: PhotoViewHeroAttributes(
                              tag: widget.imageUrls[index],
                              flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                                final Hero fromHero = fromHeroContext.widget as Hero;
                                final Hero toHero = toHeroContext.widget as Hero;

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
                            ),
                            scaleStateController: _scaleStateController,
                          );
                        },
                        itemCount: widget.imageUrls.length,
                        loadingBuilder: (context, event) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        pageController: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            currentIndex = index;
                          });
                        },
                      ),
                    ),
                  ),

                  // Nút đóng (X) ẩn đi khi vuốt kéo ảnh
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 20,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isDragging,
                      builder: (context, isDragging, _) {
                        return AnimatedOpacity(
                          opacity: isDragging ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: IconButton(
                            icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(context),
                          ),
                        );
                      },
                    ),
                  ),

                  // Số thứ tự ảnh
                  if (widget.imageUrls.length > 1)
                    Positioned(
                      bottom: 40,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isDragging,
                        builder: (context, isDragging, _) {
                          return AnimatedOpacity(
                            opacity: isDragging ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              "${currentIndex + 1} / ${widget.imageUrls.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}
