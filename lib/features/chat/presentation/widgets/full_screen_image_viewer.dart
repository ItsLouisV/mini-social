import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  static void open(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
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
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animController;
  Animation<Matrix4>? _zoomAnimation;

  // Swipe-to-dismiss state
  double _dragY = 0.0;
  double _dragStartY = 0.0;
  bool _isDismissing = false;
  bool _isZoomed = false;

  bool get _isLocalPath =>
      !widget.imageUrl.startsWith('http') && !widget.imageUrl.startsWith('blob');

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Double-tap to zoom ──────────────────────────────────────────────────────
  void _onDoubleTapDown(TapDownDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.1 ? 1.0 : 3.0;

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
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));

    _animController.addListener(_onZoomTick);
    _animController.forward(from: 0.0).then((_) {
      _animController.removeListener(_onZoomTick);
    });
  }

  void _onZoomTick() {
    if (_zoomAnimation != null) {
      _transformationController.value = _zoomAnimation!.value;
    }
  }

  // ── InteractiveViewer interaction tracking ──────────────────────────────────
  void _onInteractionStart(ScaleStartDetails details) {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final zoomed = _transformationController.value.getMaxScaleOnAxis() > 1.05;
    if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
  }

  // ── Swipe-to-dismiss (only when not zoomed) ─────────────────────────────────
  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    _dragStartY = details.globalPosition.dy;
    setState(() => _isDismissing = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDismissing) return;
    setState(() {
      _dragY = details.globalPosition.dy - _dragStartY;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDismissing) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragY.abs() > 130 || velocity.abs() > 700) {
      Navigator.pop(context);
    } else {
      setState(() {
        _isDismissing = false;
        _dragY = 0.0;
      });
    }
  }

  void _onVerticalDragCancel() {
    if (_isDismissing) {
      setState(() {
        _isDismissing = false;
        _dragY = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _isDismissing
        ? (1.0 - (_dragY.abs() / 350.0)).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Main image with pan/zoom ──────────────────────────────────
            GestureDetector(
              onTap: () {
                if (!_isZoomed) Navigator.pop(context);
              },
              // Swipe-to-dismiss gestures — only active when not zoomed
              onVerticalDragStart: _isZoomed ? null : _onVerticalDragStart,
              onVerticalDragUpdate: _isZoomed ? null : _onVerticalDragUpdate,
              onVerticalDragEnd: _isZoomed ? null : _onVerticalDragEnd,
              onVerticalDragCancel: _isZoomed ? null : _onVerticalDragCancel,
              child: AnimatedSlide(
                offset: Offset(0, _dragY / MediaQuery.of(context).size.height),
                duration: _isDismissing
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Hero(
                  tag: widget.imageUrl,
                  child: GestureDetector(
                    onDoubleTapDown: _onDoubleTapDown,
                    onDoubleTap: () {},
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      // Allow the image to expand beyond its painted bounds
                      boundaryMargin: EdgeInsets.zero,
                      clipBehavior: Clip.none,
                      // Smooth panning — no restrictive panAxis
                      panEnabled: _isZoomed,
                      scaleEnabled: true,
                      minScale: 0.5,
                      maxScale: 8.0,
                      onInteractionStart: _onInteractionStart,
                      onInteractionUpdate: _onInteractionUpdate,
                      child: SizedBox.expand(
                        child: _buildImage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Close button ──────────────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: AnimatedOpacity(
                  opacity: _isDismissing ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_isLocalPath && !kIsWeb) {
      return Image.file(
        io.File(widget.imageUrl),
        fit: BoxFit.contain,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) =>
            const Center(child: CupertinoActivityIndicator(color: Colors.white)),
        errorWidget: (_, __, ___) =>
            const Icon(CupertinoIcons.photo, color: Colors.grey, size: 50),
      );
    }
  }
}
