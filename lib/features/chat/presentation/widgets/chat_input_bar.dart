import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/message_model.dart';
import '../../providers/chat_provider.dart';
import 'voice_recorder_bar.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final String conversationId;
  final TextEditingController messageController;
  final FocusNode focusNode;
  final bool sending;
  final MessageModel? replyingToMessage;
  final XFile? pendingImage;
  final Uint8List? pendingImageWebBytes;
  final String otherUserName;
  final String currentUserId;
  final bool hasWallpaper;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelImage;

  const ChatInputBar({
    super.key,
    required this.conversationId,
    required this.messageController,
    required this.focusNode,
    required this.sending,
    this.replyingToMessage,
    this.pendingImage,
    this.pendingImageWebBytes,
    required this.otherUserName,
    required this.currentUserId,
    this.hasWallpaper = false,
    required this.onSend,
    required this.onPickImage,
    required this.onCancelReply,
    required this.onCancelImage,
  });

  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  bool _isRecordingVoice = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[widget.conversationId] ?? 'blue';
    final chatThemeColor = getChatThemePrimaryColor(themeName);

    if (_isRecordingVoice) {
      return VoiceRecorderBar(
        themeColor: chatThemeColor,
        onCancel: () => setState(() => _isRecordingVoice = false),
        onSend: (bytes, durationSeconds) async {
          setState(() => _isRecordingVoice = false);
          try {
            await ref.read(chatRepositoryProvider).sendVoiceMessage(
                  widget.conversationId,
                  bytes,
                  durationSeconds: durationSeconds,
                  replyToMessageId: widget.replyingToMessage?.id,
                );
          } catch (e) {
            debugPrint('Error sending voice message: $e');
          }
        },
      );
    }

    final hasText = widget.messageController.text.trim().isNotEmpty;
    final canSend = (hasText || widget.pendingImage != null) && !widget.sending;

    return Container(
      decoration: BoxDecoration(
        color: widget.hasWallpaper
            ? theme.scaffoldBackgroundColor.withValues(alpha: 0.85)
            : (isDark ? theme.colorScheme.surface : Colors.white),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview replying to message
            if (widget.replyingToMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: chatThemeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đang trả lời ${widget.replyingToMessage!.senderId == widget.currentUserId ? 'chính mình' : widget.otherUserName}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: chatThemeColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.replyingToMessage!.isText
                                ? (widget.replyingToMessage!.content ?? '')
                                : (widget.replyingToMessage!.isVoice
                                    ? '[Tin nhắn thoại]'
                                    : (widget.replyingToMessage!.isImage
                                        ? '[Hình ảnh]'
                                        : '[Cuộc gọi]')),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark, size: 16),
                      onPressed: widget.onCancelReply,
                      color: theme.hintColor,
                    ),
                  ],
                ),
              ),

            // Preview pending image
            if (widget.pendingImage != null)
              Container(
                padding: const EdgeInsets.all(8),
                alignment: Alignment.centerLeft,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: kIsWeb
                            ? (widget.pendingImageWebBytes != null
                                ? Image.memory(widget.pendingImageWebBytes!,
                                    fit: BoxFit.cover)
                                : Container(color: Colors.grey))
                            : Image.file(io.File(widget.pendingImage!.path),
                                fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: widget.onCancelImage,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.xmark,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Input Bar Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.photo,
                      color: chatThemeColor,
                    ),
                    onPressed: widget.onPickImage,
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: widget.messageController,
                        focusNode: widget.focusNode,
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: theme.hintColor,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (canSend)
                    GestureDetector(
                      onTap: widget.onSend,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: chatThemeColor,
                          shape: BoxShape.circle,
                        ),
                        child: widget.sending
                            ? const Center(
                                child: CupertinoActivityIndicator(
                                  radius: 9,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.arrow_up,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () => setState(() => _isRecordingVoice = true),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.mic_fill,
                          color: chatThemeColor,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
