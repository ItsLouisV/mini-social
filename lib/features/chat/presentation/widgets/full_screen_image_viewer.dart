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
        barrierColor: Colors.black.withValues(alpha: 0.9),
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

class _FullScreenImageViewerState extends State<FullScreenImageViewer> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  // Swipe/Drag to dismiss fields
  double _dragOffset = 0.0;
  bool _isDragging = false;

  bool get _isLocalPath => !widget.imageUrl.startsWith('http') && !widget.imageUrl.startsWith('blob');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    final double currentScale = _transformationController.value.getMaxScaleOnAxis();
    final double targetScale = currentScale > 1.1 ? 1.0 : 3.0;

    final Matrix4 endMatrix;
    if (targetScale == 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details.localPosition;
      // ignore: deprecated_member_use
      endMatrix = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-position.dx * (targetScale - 1), -position.dy * (targetScale - 1))
        // ignore: deprecated_member_use
        ..scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animationController.addListener(_onZoomAnimationUpdate);
    _animationController.forward(from: 0.0).then((_) {
      _animationController.removeListener(_onZoomAnimationUpdate);
    });
  }

  void _onZoomAnimationUpdate() {
    if (_zoomAnimation != null) {
      _transformationController.value = _zoomAnimation!.value;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final double currentScale = _transformationController.value.getMaxScaleOnAxis();
    // Only allow swipe to dismiss when image is not zoomed in
    if (currentScale > 1.1) return;

    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;
      _isDragging = true;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragOffset.abs() > 140 || velocity.abs() > 800) {
      // Dismiss the viewer
      Navigator.pop(context);
    } else {
      // Snap back to center
      setState(() {
        _isDragging = false;
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - (_dragOffset.abs() / 400.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9 * opacity),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Interactive viewer with hero animation
            GestureDetector(
              onTap: () => Navigator.pop(context),
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: Transform.translate(
                offset: Offset(0.0, _dragOffset),
                child: Center(
                  child: Hero(
                    tag: widget.imageUrl,
                    child: GestureDetector(
                      onDoubleTapDown: _onDoubleTapDown,
                      onDoubleTap: () {}, // Handled by DoubleTapDown
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: _buildImage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Cupertino X button top right
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
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
        placeholder: (_, __) => const Center(child: CupertinoActivityIndicator(color: Colors.white)),
        errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, color: Colors.grey, size: 50),
      );
    }
  }
}
