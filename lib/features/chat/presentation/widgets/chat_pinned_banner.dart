import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../domain/pinned_message_model.dart';
import '../../providers/chat_provider.dart';
import '../../domain/message_model.dart';

class ChatPinnedBanner extends ConsumerStatefulWidget {
  final String conversationId;
  final List<PinnedMessageModel> pinnedList;
  final String currentUserId;
  final String otherUserName;
  final bool hasWallpaper;
  final Function(PinnedMessageModel) onJumpToMessage;
  final Function(String messageId) onUnpinMessage;

  const ChatPinnedBanner({
    super.key,
    required this.conversationId,
    required this.pinnedList,
    required this.currentUserId,
    required this.otherUserName,
    this.hasWallpaper = false,
    required this.onJumpToMessage,
    required this.onUnpinMessage,
  });

  @override
  ConsumerState<ChatPinnedBanner> createState() => _ChatPinnedBannerState();
}

class _ChatPinnedBannerState extends ConsumerState<ChatPinnedBanner> {
  bool _isExpanded = false;

  Widget? _buildMediaPreview(MessageModel msg, Color accentColor, {double size = 36}) {

    // Image
    if (msg.isImage) {
      final mediaUrl = msg.firstMediaUrl;

      if (mediaUrl == null || mediaUrl.isEmpty) return null;

      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: CachedNetworkImage(
          imageUrl: mediaUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            color: accentColor.withValues(alpha: 0.1),
            child: const Center(
              child: CupertinoActivityIndicator(radius: 8),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: size,
            height: size,
            color: accentColor.withValues(alpha: 0.1),
            child: Icon(
              CupertinoIcons.photo,
              size: 17,
              color: accentColor,
            ),
          ),
        ),
      );
    }

    // Voice
    if (msg.isVoice) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: FaIcon(
          FontAwesomeIcons.creativeCommonsSampling,
          size: 22,
          color: accentColor,
        ),
      );
    }

    // Call
    if (msg.isCall) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          CupertinoIcons.phone_fill,
          size: 20,
          color: accentColor,
        ),
      );
    }

    // Other
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pinnedList.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final latestPin = widget.pinnedList.first;
    final latestMsg = latestPin.message;

    if (latestMsg == null) return const SizedBox.shrink();

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[widget.conversationId] ?? 'blue';
    final accentColor = getChatThemePrimaryColor(themeName);

    String _getSenderName(MessageModel msg) {
      if (msg.senderId == widget.currentUserId) {
        return 'Bạn';
      }
      return msg.senderName?.trim().isNotEmpty == true
          ? msg.senderName!
          : widget.otherUserName;
    }

    String _getContentSnippet(MessageModel msg) {
      if (msg.isText) {
        final text = msg.content?.trim();
        return text?.isNotEmpty == true ? text! : '[Tin nhắn]';
      }
      if (msg.isImage) {
        return '[Hình ảnh]';
      }
      if (msg.isVoice) {
        return '[Voice Message]';
      }
      if (msg.isCall) {
        return '[Cuộc gọi]';
      }
      if (msg.isRecalled) {
        return '[Revoked message]';
      }
      if (msg.isSystem) {
        return '[Tin nhắn hệ thống]';
      }
      return '[Tin nhắn]';
    }

    final contentSnippet = _getContentSnippet(latestMsg);

    final senderName = _getSenderName(latestMsg);

    final bannerBgColor = widget.hasWallpaper
        ? (isDark
            ? Colors.black.withValues(alpha: 0.65)
            : Colors.white.withValues(alpha: 0.75))
        : (isDark
            ? const Color(0xFF1E1E2C).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.92));

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : accentColor.withValues(alpha: 0.2);

    final mediaPreview = _buildMediaPreview(latestMsg, accentColor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: bannerBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main Banner Header
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (widget.pinnedList.length > 1) {
                        setState(() => _isExpanded = !_isExpanded);
                      } else {
                        widget.onJumpToMessage(latestPin);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Glowing Pin Icon Badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.25),
                                  accentColor.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                CupertinoIcons.pin_fill,
                                size: 15,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Tin nhắn ghim',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (widget.pinnedList.length > 1) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: accentColor,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${widget.pinnedList.length}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$senderName: ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.95)
                                              : Colors.black87,
                                        ),
                                      ),
                                      TextSpan(
                                        text: contentSnippet,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (mediaPreview != null) ...[
                            const SizedBox(width: 8),
                            mediaPreview,
                          ],

                          const SizedBox(width: 6),

                          // Action Button (Expand toggle or Unpin button)
                          if (widget.pinnedList.length > 1)
                            AnimatedRotation(
                              turns: _isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOutCubic,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 14,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            )
                          else
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 28,
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                widget.onUnpinMessage(latestPin.messageId);
                              },
                              child: const Icon(
                                CupertinoIcons.trash_fill,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Expanded List of all Pinned Messages (Smooth animated expand)
                  if (_isExpanded && widget.pinnedList.length > 1)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: widget.pinnedList.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 14,
                          endIndent: 14,
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                        itemBuilder: (context, index) {
                          final pin = widget.pinnedList[index];
                          final msg = pin.message;
                          if (msg == null) return const SizedBox.shrink();

                          final pinSnippet = _getContentSnippet(msg);

                          final pinSender = _getSenderName(msg);

                          // final pinMedia = msg.firstMediaUrl;

                          // final pinHasThumb = msg.isImage && pinMedia != null && pinMedia.isNotEmpty;

                          final pinMediaPreview = _buildMediaPreview(msg, accentColor, size: 28);

                          return InkWell(
                            onTap: () {
                              setState(() => _isExpanded = false);
                              widget.onJumpToMessage(pin);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.pin_fill,
                                      size: 12,
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '$pinSender: $pinSnippet',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // if (pinHasThumb) ...[
                                  //   const SizedBox(width: 8),
                                  //   ClipRRect(
                                  //     borderRadius: BorderRadius.circular(6),
                                  //     child: CachedNetworkImage(
                                  //       imageUrl: pinMedia!,
                                  //       width: 28,
                                  //       height: 28,
                                  //       fit: BoxFit.cover,
                                  //     ),
                                  //   ),
                                  // ],

                                  if (pinMediaPreview != null) ...[
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: FittedBox(
                                        child: pinMediaPreview!,
                                      ),
                                    ),
                                  ],

                                  const SizedBox(width: 4),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minSize: 28,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      widget.onUnpinMessage(pin.messageId);
                                    },
                                    child: const Icon(
                                      CupertinoIcons.trash,
                                      size: 15,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
