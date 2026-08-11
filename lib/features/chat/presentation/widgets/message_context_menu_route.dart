import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class MessageContextMenuRoute<T> extends PageRouteBuilder<T> {
  final Offset messagePosition;
  final Size messageSize;
  final Widget messageWidget;
  final Widget menuContentWidget;
  final bool isMine;
  final double estimatedMenuHeight;
  final bool keepAnchorVisible;
  final double backdropOpacity;
  final double anchorMenuGap;
  final bool allowScaleOvershoot;

  MessageContextMenuRoute({
    required this.messagePosition,
    required this.messageSize,
    required this.messageWidget,
    required this.menuContentWidget,
    required this.isMine,
    this.estimatedMenuHeight = 246.0,
    this.keepAnchorVisible = false,
    this.backdropOpacity = 0.6,
    this.anchorMenuGap = 16.0,
    this.allowScaleOvershoot = true,
  }) : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (context, animation, secondaryAnimation) {
            return _MessageContextMenuOverlay(
              messagePosition: messagePosition,
              messageSize: messageSize,
              messageWidget: messageWidget,
              menuContentWidget: menuContentWidget,
              isMine: isMine,
              animation: animation,
              menuHeight: estimatedMenuHeight,
              keepAnchorVisible: keepAnchorVisible,
              backdropOpacity: backdropOpacity,
              anchorMenuGap: anchorMenuGap,
              allowScaleOvershoot: allowScaleOvershoot,
            );
          },
        );
}

class _MessageContextMenuOverlay extends StatelessWidget {
  final Offset messagePosition;
  final Size messageSize;
  final Widget messageWidget;
  final Widget menuContentWidget;
  final bool isMine;
  final Animation<double> animation;
  final double menuHeight;
  final bool keepAnchorVisible;
  final double backdropOpacity;
  final double anchorMenuGap;
  final bool allowScaleOvershoot;

  const _MessageContextMenuOverlay({
    required this.messagePosition,
    required this.messageSize,
    required this.messageWidget,
    required this.menuContentWidget,
    required this.isMine,
    required this.animation,
    required this.menuHeight,
    required this.keepAnchorVisible,
    required this.backdropOpacity,
    required this.anchorMenuGap,
    required this.allowScaleOvershoot,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    const menuWidth = 290.0;
    
    // Decide whether to place menu above or below the bubble
    final spaceBelow = screenHeight - (messagePosition.dy + messageSize.height);
    // Member actions follow the Messenger/Zalo pattern: the selected member
    // stays above the actions. If space is tight, both are moved upward.
    final placeMenuAbove = !keepAnchorVisible &&
        spaceBelow < menuHeight &&
        messagePosition.dy > menuHeight;

    // Vector to center of screen
    final bubbleCenterX = messagePosition.dx + messageSize.width / 2;
    final bubbleCenterY = messagePosition.dy + messageSize.height / 2;
    final dxToCenter = (screenWidth / 2) - bubbleCenterX;
    final dyToCenter = (screenHeight / 2) - bubbleCenterY;

    // Wrap the message bubble in Material to prevent double underlines / text styling issues in overlay
    final wrappedBubble = Material(
      color: Colors.transparent,
      child: IgnorePointer(
        child: SizedBox(
          width: messageSize.width,
          height: messageSize.height,
          child: messageWidget,
        ),
      ),
    );

    // Fast scale-up animation with bounce curve
    final scaleAnimation = Tween<double>(
      begin: allowScaleOvershoot ? 0.92 : 0.96,
      end: allowScaleOvershoot ? 1.05 : 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve:
            allowScaleOvershoot ? Curves.easeOutBack : Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );

    final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss area
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: FadeTransition(
              opacity: opacityAnimation,
              child: kIsWeb
                  ? Container(
                      color: Colors.black.withValues(alpha: backdropOpacity),
                    )
                  : BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: (backdropOpacity - 0.6)
                              .clamp(0.0, 0.3)
                              .toDouble(),
                        ),
                      ),
                    ),
            ),
          ),
          // Animated Bubble & Menu using AnimatedBuilder to animate position towards screen center
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // Diagonal shift towards center (10% of distance)
              final shiftFactor = 0.10 * animation.value;
              final animatedBubbleLeft = messagePosition.dx + (dxToCenter * shiftFactor);
              var animatedBubbleTop = messagePosition.dy + (dyToCenter * shiftFactor);

              // Member-action menus can be taller than the remaining viewport.
              // Move the anchor and menu as one unit so neither covers the other.
              if (keepAnchorVisible) {
                const safeTop = 20.0;
                const safeBottom = 20.0;
                final menuGap = anchorMenuGap;

                final maxBubbleTop = screenHeight -
                    safeBottom -
                    messageSize.height -
                    menuGap -
                    menuHeight;
                final contentFitsViewport = messageSize.height +
                        menuGap +
                        menuHeight <=
                    screenHeight - safeTop - safeBottom;

                // If a message itself is taller than the viewport, allow its
                // top edge to move beyond the screen. The action menu remains
                // fully visible below it, matching modern chat applications.
                final targetBubbleTop = contentFitsViewport
                    ? messagePosition.dy
                        .clamp(safeTop, maxBubbleTop)
                        .toDouble()
                    : (messagePosition.dy < maxBubbleTop
                        ? messagePosition.dy
                        : maxBubbleTop);

                animatedBubbleTop = messagePosition.dy +
                    ((targetBubbleTop - messagePosition.dy) * animation.value);
              }

              // Horizontal positioning for the menu based on animated bubble position
              double menuLeft;
              if (isMine) {
                menuLeft = animatedBubbleLeft + messageSize.width - menuWidth;
              } else {
                menuLeft = animatedBubbleLeft;
              }
              menuLeft = menuLeft.clamp(12.0, screenWidth - menuWidth - 12.0);

              // Vertical positioning for menu
              double menuTop;
              if (placeMenuAbove) {
                menuTop = animatedBubbleTop - menuHeight - anchorMenuGap;
                menuTop = menuTop.clamp(20.0, screenHeight - menuHeight - 20.0);
              } else {
                menuTop = animatedBubbleTop + messageSize.height + anchorMenuGap;
                menuTop = menuTop.clamp(20.0, screenHeight - menuHeight - 20.0);
              }

              return Stack(
                children: [
                  Positioned(
                    left: animatedBubbleLeft,
                    top: animatedBubbleTop,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: wrappedBubble,
                    ),
                  ),
                  Positioned(
                    left: menuLeft,
                    top: menuTop,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: FadeTransition(
                        opacity: opacityAnimation,
                        child: menuContentWidget,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
