import 'dart:io' as io;
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/message_model.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;
  XFile? _pendingImage;
  Uint8List? _pendingImagePreviewBytes;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markAsSeen(widget.conversationId);
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(realtimeMessagesProvider(widget.conversationId).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final image = _pendingImage;

    if (text.isEmpty && image == null) return;
    if (_sending) return;

    setState(() {
      _sending = true;
      _pendingImage = null;
      _pendingImagePreviewBytes = null;
    });
    _messageController.clear();

    try {
      // Gửi ảnh trước (nếu có)
      if (image != null) {
        await ref
            .read(chatRepositoryProvider)
            .sendImageMessage(widget.conversationId, image);
      }
      // Gửi text sau (nếu có — dùng như caption)
      if (text.isNotEmpty) {
        await ref
            .read(chatRepositoryProvider)
            .sendMessage(widget.conversationId, text);
      }
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gửi thất bại: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        debugPrint('Gửi thất bại: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Chọn ảnh từ thư viện → hiển thị preview trên thanh input (chưa gửi)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Trên web cần đọc bytes trước để hiện preview
    Uint8List? previewBytes;
    if (kIsWeb) {
      previewBytes = await picked.readAsBytes();
    }

    setState(() {
      _pendingImage = picked;
      _pendingImagePreviewBytes = previewBytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(realtimeMessagesProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    final theme = Theme.of(context);

    ref.listen(realtimeMessagesProvider(widget.conversationId),
        (_, next) {
      next.whenData((_) {
        if (_scrollController.hasClients && _scrollController.offset < 100) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      });
    });

    // Lấy info người kia từ conversations provider
    final convAsync = ref.watch(conversationsProvider);
    final otherUser = convAsync.whenData((convs) {
      try {
        return convs
            .firstWhere((c) => c.id == widget.conversationId)
            .otherUser;
      } catch (_) {
        return null;
      }
    }).valueOrNull;

    final otherUserName = otherUser?.displayName ?? 'Chat';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                CupertinoIcons.chevron_back,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              onPressed: () => context.pop(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Flexible(
              child: GestureDetector(
                onTap: () {
                  if (otherUser != null) {
                    context.push('/profile/${otherUser.id}');
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAvatar(
                      imageUrl: otherUser?.avatarUrl,
                      name: otherUser?.displayName,
                      radius: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        otherUserName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Video call
          IconButton(
            icon: Icon(
              CupertinoIcons.videocam,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            onPressed: () {
              if (otherUser?.id == null) return;
              context.push('/call/outgoing', extra: {
                'conversationId': widget.conversationId,
                'calleeId': otherUser!.id,
                'calleeName': otherUserName,
                'avatarUrl':  otherUser.avatarUrl,
                'isVideo':    true,
              });
            },
            tooltip: 'Gọi video',
          ),
          // Voice call
          IconButton(
            icon: Icon(
              CupertinoIcons.phone,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            onPressed: () {
              if (otherUser?.id == null) return;
              context.push('/call/outgoing', extra: {
                'conversationId': widget.conversationId,
                'calleeId': otherUser!.id,
                'calleeName': otherUserName,
                'avatarUrl':  otherUser.avatarUrl,
                'isVideo':    false,
              });
            },
            tooltip: 'Gọi thoại',
          ),
          // More options
          IconButton(
            icon: Icon(
              CupertinoIcons.ellipsis,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            onPressed: () {},
            tooltip: 'Thêm',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) =>
                    _buildMessageList(messages, currentUserId),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
            ),
            _buildInput(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(
      List<MessageModel> messages, String currentUserId) {
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Hãy gửi tin nhắn đầu tiên!',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    // Build message items with grouping logic for reversed list
    final items = <_MessageListItem>[];

    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      // chronologically prev message is older (higher index)
      final prev = i < messages.length - 1 ? messages[i + 1] : null;
      // chronologically next message is newer (lower index)
      final next = i > 0 ? messages[i - 1] : null;

      // Xác định có phải tin cuối trong nhóm không
      // (nhóm: cùng người gửi, khoảng cách < 5 phút)
      final isLastInGroup = next == null ||
          next.senderId != msg.senderId ||
          next.createdAt.difference(msg.createdAt).inMinutes.abs() >= 5;

      items.add(_MessageListItem.message(
        msg,
        isLastInGroup: isLastInGroup,
        showInlineTime: isLastInGroup,
      ));

      // Show time divider nếu cách nhau >= 10 phút hoặc tin nhắn đầu tiên
      if (prev == null ||
          msg.createdAt.difference(prev.createdAt).inMinutes.abs() >= 10) {
        items.add(_MessageListItem.divider(msg.createdAt));
      }
    }

    // Mark as seen
    final isMine = messages.isNotEmpty &&
        messages.first.senderId == currentUserId;
    final lastIsSeen = messages.isNotEmpty && messages.first.isSeen;

    // Lấy trạng thái loading từ provider
    final isLoadingMore = ref.read(realtimeMessagesProvider(widget.conversationId).notifier).isLoadingMore;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final item = items[index];
        if (item.isDivider) {
          return _TimeDivider(dateTime: item.dateTime!);
        }
        return _MessageBubble(
          key: ValueKey(item.message!.id),
          message: item.message!,
          isMine: item.message!.senderId == currentUserId,
          showInlineTime: item.showInlineTime,
          showSeen: isMine &&
              lastIsSeen &&
              index == 0, // Mới nhất là index 0
        );
      },
    );
  }

  // ── Image Preview (kiểu Zalo) ────────────────────────────────────────────────
  Widget _buildImagePreview(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final image = _pendingImage!;

    Widget thumbnail;
    if (kIsWeb && _pendingImagePreviewBytes != null) {
      thumbnail = Image.memory(
        _pendingImagePreviewBytes!,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb) {
      thumbnail = Image.file(
        io.File(image.path),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
      );
    } else {
      // web nhưng chưa load bytes xong
      thumbnail = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(CupertinoIcons.photo, color: theme.hintColor, size: 28),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail + nút xoá
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: thumbnail,
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _pendingImage = null;
                    _pendingImagePreviewBytes = null;
                  }),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Tên file
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1 ảnh đã chọn',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  image.name,
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Input bar ────────────────────────────────────────────────────────────────
  Widget _buildInput(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hasPendingImage = _pendingImage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Zalo-style: hiện preview ảnh đang chờ gửi
        if (hasPendingImage) _buildImagePreview(theme),

        // Thanh nhập liệu
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Nút chọn ảnh (icon sáng khi đã chọn)
              IconButton(
                onPressed: _sending ? null : _pickImage,
                icon: Icon(
                  CupertinoIcons.photo,
                  color: hasPendingImage
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white60 : Colors.black45),
                  size: 24,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),

              // Text field
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText:
                          hasPendingImage ? 'Thêm chú thích...' : 'Nhắn tin...',
                      hintStyle:
                          TextStyle(color: theme.hintColor, fontSize: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Nút gửi — sáng khi có text HOẶC có ảnh pending
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, _) {
                  final hasContent =
                      value.text.trim().isNotEmpty || hasPendingImage;
                  final bgColor = hasContent
                      ? AppColors.chatInputSendEnabled
                      : (isDark
                          ? AppColors.darkChatInputSendDisabled
                          : AppColors.chatInputSendDisabled);
                  final iconColor = hasContent
                      ? AppColors.chatInputSendIconEnabled
                      : AppColors.chatInputSendIconDisabled;

                  return GestureDetector(
                    onTap: (hasContent && !_sending) ? _send : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              CupertinoIcons.paperplane_fill,
                              color: iconColor,
                              size: 18,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helper data class ─────────────────────────────────────────────────────────
class _MessageListItem {
  final bool isDivider;
  final DateTime? dateTime;
  final MessageModel? message;
  final bool showInlineTime;

  const _MessageListItem._({
    required this.isDivider,
    this.dateTime,
    this.message,
    this.showInlineTime = false,
  });

  factory _MessageListItem.divider(DateTime dt) =>
      _MessageListItem._(isDivider: true, dateTime: dt);

  factory _MessageListItem.message(
    MessageModel msg, {
    bool isLastInGroup = true,
    bool showInlineTime = true,
  }) =>
      _MessageListItem._(
        isDivider: false,
        message: msg,
        showInlineTime: showInlineTime,
      );
}

// ── Time Divider ──────────────────────────────────────────────────────────────
class _TimeDivider extends StatelessWidget {
  final DateTime dateTime;

  const _TimeDivider({required this.dateTime});

  String _format() {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sixDaysAgo = today.subtract(const Duration(days: 6));
    final dateOnly =
        DateTime(local.year, local.month, local.day);
    final hhmm = local.localTimeHHmm;

    if (dateOnly == today) {
      return hhmm;
    } else if (dateOnly == yesterday) {
      return 'Hôm qua, $hhmm';
    } else if (dateOnly.isAfter(sixDaysAgo)) {
      const days = [
        'Chủ Nhật',
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy'
      ];
      final idx = local.weekday == 7 ? 0 : local.weekday;
      return '${days[idx]}, $hhmm';
    } else {
      final d = local.day.toString().padLeft(2, '0');
      final mo = local.month.toString().padLeft(2, '0');
      return '$d/$mo/${local.year}, $hhmm';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _format(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.hintColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool showInlineTime;
  final bool showSeen;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showInlineTime = false,
    this.showSeen = false,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _tapped = false;

  String get _timeStr {
    final local = widget.message.createdAt.isUtc
        ? widget.message.createdAt.toLocal()
        : widget.message.createdAt;
    return local.localTimeHHmm;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMine = widget.isMine;
    final message = widget.message;

    // Colors - Using AppColors
    final myBubbleColor = isDark ? AppColors.darkChatBubbleSender : AppColors.chatBubbleSender;
    final theirBubbleColor = isDark ? AppColors.darkChatBubbleReceiver : AppColors.chatBubbleReceiver;
    final myTextColor = isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender;
    final theirTextColor = isDark ? AppColors.darkChatTextReceiver : AppColors.chatTextReceiver;

    // Show time when: tapped OR (it's the last in group AND showInlineTime)
    final showTime = _tapped || widget.showInlineTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _tapped = !_tapped),
            child: Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bubble content
                Container(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? myBubbleColor : theirBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                  ),
                  child: message.isImage && message.mediaUrl != null
                      ? _ImageBubble(
                          url: message.mediaUrl!,
                          isMine: isMine,
                        )
                      : message.isCall
                          ? _CallLogBubble(message: message, isMine: isMine)
                          : Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                          child: Text(
                            message.content ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              color: isMine ? myTextColor : theirTextColor,
                              height: 1.35,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Time + seen indicator (animated)
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: showTime
                ? Padding(
                    padding: EdgeInsets.only(
                      top: 3,
                      bottom: 4,
                      left: isMine ? 0 : 6,
                      right: isMine ? 6 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: isMine
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Text(
                          _timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.hintColor,
                          ),
                        ),
                        if (widget.showSeen) ...[
                          const SizedBox(width: 4),
                          Text(
                            '• Đã xem',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

// ── Image Bubble ──────────────────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  final String url;
  final bool isMine;

  const _ImageBubble({required this.url, required this.isMine});

  bool get _isLocalPath =>
      !url.startsWith('http') && !url.startsWith('blob');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isMine ? 18 : 4),
        bottomRight: Radius.circular(isMine ? 4 : 18),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 300,
        ),
        child: _isLocalPath && !kIsWeb
            ? Image.file(
                io.File(url),
                fit: BoxFit.cover,
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 200,
                  height: 160,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 200,
                  height: 160,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child: const Icon(CupertinoIcons.photo,
                      color: Colors.grey),
                ),
              ),
      ),
    );
  }
}

// ── Call Log Bubble ───────────────────────────────────────────────────────────
class _CallLogBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _CallLogBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isMine 
        ? (isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender)
        : (isDark ? AppColors.darkChatTextReceiver : AppColors.chatTextReceiver);
    
    final content = message.content ?? '';
    final isMissed = content.toLowerCase().contains('nhỡ') || content.toLowerCase().contains('từ chối') || content.toLowerCase().contains('đã hủy');
    final isVideo = content.toLowerCase().contains('video');
    final color = isMissed ? AppColors.error : textColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMine ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.phone_fill,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: isMissed ? color : textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
