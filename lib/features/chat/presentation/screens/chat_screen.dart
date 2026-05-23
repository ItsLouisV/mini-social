import 'dart:io' as io;
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/message_model.dart';
import '../../domain/pinned_message_model.dart';
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
  MessageModel? _replyingToMessage;
  bool _pinnedListExpanded = false;

  // Quản lý GlobalKey cho việc cuộn tới tin nhắn được trả lời
  final Map<String, GlobalKey<_MessageBubbleState>> _messageKeys = {};

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

  // Cuộn tới tin nhắn gốc và tạo hiệu ứng nhấp nháy
  void _scrollToMessage(String msgId) {
    final key = _messageKeys[msgId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // Cuộn sao cho phần tử nằm ở giữa màn hình
      );
      key.currentState?.highlight();
      return;
    }

    // Nếu không tìm thấy Context nhưng tin nhắn có trong state (ngoài viewport)
    final messages = ref.read(realtimeMessagesProvider(widget.conversationId)).valueOrNull ?? [];
    final index = messages.indexWhere((m) => m.id == msgId);
    if (index != -1 && _scrollController.hasClients) {
      final estOffset = index * 110.0; // Ước lượng 110px mỗi bubble
      final maxScroll = _scrollController.position.maxScrollExtent;
      final target = estOffset.clamp(0.0, maxScroll);
      
      _scrollController.jumpTo(target);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retryKey = _messageKeys[msgId];
        if (retryKey?.currentContext != null) {
          Scrollable.ensureVisible(
            retryKey!.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
          retryKey.currentState?.highlight();
        }
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tin nhắn gốc đã cũ hoặc không tìm thấy'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    final image = _pendingImage;
    final replyId = _replyingToMessage?.id;

    if (text.isEmpty && image == null) return;
    if (_sending) return;

    setState(() {
      _sending = true;
      _pendingImage = null;
      _pendingImagePreviewBytes = null;
      _replyingToMessage = null; // Xoá reply preview ngay lập tức
    });
    _messageController.clear();

    try {
      if (image != null) {
        // Gửi tin nhắn ảnh kèm chú thích (caption) và đính kèm ID reply (nếu có)
        await ref
            .read(chatRepositoryProvider)
            .sendImageMessage(
              widget.conversationId, 
              image,
              caption: text.isNotEmpty ? text : null,
              replyToMessageId: replyId,
            );
      } else {
        // Chỉ gửi tin nhắn chữ và đính kèm ID reply (nếu có)
        if (text.isNotEmpty) {
          await ref
              .read(chatRepositoryProvider)
              .sendMessage(
                widget.conversationId, 
                text,
                replyToMessageId: replyId,
              );
        }
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
    final pinnedAsync = ref.watch(pinnedMessagesProvider(widget.conversationId));
    final pinnedMessages = pinnedAsync.valueOrNull ?? [];
    final pinnedIds = pinnedMessages.map((pm) => pm.messageId).toSet();

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
            if (pinnedMessages.isNotEmpty) _buildPinnedMessagesBar(theme, pinnedMessages, currentUserId, otherUserName),
            Expanded(
              child: messagesAsync.when(
                data: (messages) =>
                    _buildMessageList(messages, currentUserId, otherUserName, pinnedIds),
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
      List<MessageModel> messages, String currentUserId, String otherUserName, Set<String> pinnedIds) {
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

        final msgId = item.message!.id;
        final bubbleKey = _messageKeys.putIfAbsent(msgId, () => GlobalKey<_MessageBubbleState>());

        return _MessageBubble(
          key: bubbleKey,
          message: item.message!,
          isMine: item.message!.senderId == currentUserId,
          showInlineTime: item.showInlineTime,
          showSeen: isMine &&
              lastIsSeen &&
              index == 0, // Mới nhất là index 0
          currentUserId: currentUserId,
          otherUserName: otherUserName,
          isPinned: pinnedIds.contains(msgId),
          onPin: () async {
            try {
              await ref.read(chatRepositoryProvider).pinMessage(widget.conversationId, msgId);
              ref.invalidate(pinnedMessagesProvider(widget.conversationId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ghim thất bại: ${e.toString()}')),
                );
              }
            }
          },
          onUnpin: () async {
            try {
              await ref.read(chatRepositoryProvider).unpinMessage(widget.conversationId, msgId);
              ref.invalidate(pinnedMessagesProvider(widget.conversationId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bỏ ghim thất bại: ${e.toString()}')),
                );
              }
            }
          },
          onSwipeToReply: () {
            setState(() {
              _replyingToMessage = item.message;
              _focusNode.requestFocus();
            });
          },
          onTapReply: (replyMsgId) => _scrollToMessage(replyMsgId),
        );
      },
    );
  }

  // ── Jump to Pinned Message (Cuộn & Tải tin cũ nếu cần) ──────────────────────
  Future<void> _jumpToPinnedMessage(PinnedMessageModel pin) async {
    final msgId = pin.messageId;
    
    // Kiểm tra xem tin nhắn đã có trong state hiện tại không
    final notifier = ref.read(realtimeMessagesProvider(widget.conversationId).notifier);
    final messages = ref.read(realtimeMessagesProvider(widget.conversationId)).valueOrNull ?? [];
    final hasMsg = messages.any((m) => m.id == msgId);

    if (hasMsg) {
      _scrollToMessage(msgId);
      return;
    }

    // Nếu không có, tiến hành tải thêm từ DB
    final msg = pin.message;
    if (msg == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CupertinoActivityIndicator(color: Colors.white),
              SizedBox(width: 12),
              Text('Đang tải tin nhắn gốc...'),
            ],
          ),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      await notifier.loadUpToMessage(msg.createdAt);
      // Đợi UI rebuild và cuộn
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToMessage(msgId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải tin nhắn gốc: ${e.toString()}')),
        );
      }
    }
  }

  // ── Pinned Messages Bar (kiểu Zalo) ──────────────────────────────────────────
  Widget _buildPinnedMessagesBar(
    ThemeData theme,
    List<PinnedMessageModel> pinnedList,
    String currentUserId,
    String otherUserName,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    // Tin ghim mới nhất (đứng đầu danh sách)
    final latestPin = pinnedList.first;
    final latestMsg = latestPin.message;

    if (latestMsg == null) return const SizedBox.shrink();

    // Định dạng nội dung hiển thị
    String contentSnippet = '';
    if (latestMsg.isText) {
      contentSnippet = latestMsg.content ?? '';
    } else if (latestMsg.isImage) {
      contentSnippet = '[Hình ảnh]';
    } else if (latestMsg.isCall) {
      contentSnippet = '[Cuộc gọi]';
    } else {
      contentSnippet = '[Tin nhắn]';
    }

    final senderName = latestMsg.senderId == currentUserId ? 'Bạn' : otherUserName;

    // Chiều cao / màu sắc
    final barBgColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE8F4FD);
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : const Color(0xFF0068FF),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Thanh ghim chính
        GestureDetector(
          onTap: () {
            if (pinnedList.length > 1) {
              setState(() {
                _pinnedListExpanded = !_pinnedListExpanded;
              });
            } else {
              _jumpToPinnedMessage(latestPin);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: barBgColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.pin_fill,
                  size: 16,
                  color: isDark ? Colors.white70 : const Color(0xFF0068FF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ghim: $senderName: $contentSnippet',
                    style: textStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Nút thao tác bên phải
                if (pinnedList.length > 1)
                  Icon(
                    _pinnedListExpanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: theme.hintColor,
                  )
                else
                  // Nếu chỉ có 1 tin ghim, cho phép bấm trực tiếp X để bỏ ghim
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .unpinMessage(widget.conversationId, latestPin.messageId);
                        ref.invalidate(pinnedMessagesProvider(widget.conversationId));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bỏ ghim thất bại: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Danh sách ghim mở rộng (nếu có nhiều tin ghim và đang expanded)
        if (_pinnedListExpanded && pinnedList.length > 1)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: pinnedList.length,
              separatorBuilder: (context, index) => Divider(
                height: 0.5,
                thickness: 0.5,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final pin = pinnedList[index];
                final msg = pin.message;
                if (msg == null) return const SizedBox.shrink();

                String pinSnippet = '';
                if (msg.isText) {
                  pinSnippet = msg.content ?? '';
                } else if (msg.isImage) {
                  pinSnippet = '[Hình ảnh]';
                } else if (msg.isCall) {
                  pinSnippet = '[Cuộc gọi]';
                } else {
                  pinSnippet = '[Tin nhắn]';
                }

                final pinSender = msg.senderId == currentUserId ? 'Bạn' : otherUserName;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    CupertinoIcons.pin,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    '$pinSender: $pinSnippet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  onTap: () {
                    _jumpToPinnedMessage(pin);
                  },
                  trailing: GestureDetector(
                    onTap: () async {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .unpinMessage(widget.conversationId, pin.messageId);
                        ref.invalidate(pinnedMessagesProvider(widget.conversationId));
                        // Nếu sau khi unpin chỉ còn <= 1 tin, tự động thu gọn
                        if (pinnedList.length <= 2) {
                          setState(() {
                            _pinnedListExpanded = false;
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bỏ ghim thất bại: ${e.toString()}')),
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Icon(
                        CupertinoIcons.trash,
                        size: 14,
                        color: theme.colorScheme.error.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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

  // ── Reply Preview ─────────────────────────────────────────────────────────────
  Widget _buildReplyPreview(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    
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
    final otherUserName = otherUser?.displayName ?? 'Người dùng';

    final senderName = _replyingToMessage!.senderId == currentUserId
        ? 'Bạn'
        : otherUserName;

    final replyContent = _replyingToMessage!.isText 
        ? _replyingToMessage!.content 
        : (_replyingToMessage!.isImage ? 'Hình ảnh' : 'Cuộc gọi');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Cột màu dọc bên trái phong cách Zalo
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          
          // Chi tiết tin nhắn reply
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Trả lời $senderName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyContent ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          // Hiển thị thumbnail ảnh nhỏ nếu phản hồi một tin nhắn ảnh
          if (_replyingToMessage!.isImage && _replyingToMessage!.mediaUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: _replyingToMessage!.mediaUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.withValues(alpha: 0.2), width: 32, height: 32),
                  errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 16),
                ),
              ),
            ),
            
          // Nút huỷ reply
          IconButton(
            onPressed: () => setState(() => _replyingToMessage = null),
            icon: const Icon(CupertinoIcons.xmark, size: 16),
            color: theme.hintColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
        // Hiển thị tin nhắn đang Reply
        if (_replyingToMessage != null) _buildReplyPreview(theme),

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
  final VoidCallback? onSwipeToReply;
  final String currentUserId;
  final String otherUserName;
  final ValueChanged<String>? onTapReply;
  final bool isPinned;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showInlineTime = false,
    this.showSeen = false,
    this.onSwipeToReply,
    required this.currentUserId,
    required this.otherUserName,
    this.onTapReply,
    this.isPinned = false,
    this.onPin,
    this.onUnpin,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _tapped = false;
  bool _isHighlighted = false;

  String get _timeStr {
    final local = widget.message.createdAt.isUtc
        ? widget.message.createdAt.toLocal()
        : widget.message.createdAt;
    return local.localTimeHHmm;
  }

  // Hàm kích hoạt hiệu ứng highlight (nhấp nháy bong bóng) khi click từ reply
  void highlight() {
    setState(() => _isHighlighted = true);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _isHighlighted = false);
      }
    });
  }

  // Hiển thị Context Menu khi nhấn giữ (Mobile) hoặc chuột phải (Web/Desktop)
  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);

    final List<PopupMenuEntry<String>> menuItems = [
      PopupMenuItem<String>(
        value: 'reply',
        child: Row(
          children: [
            Icon(
              CupertinoIcons.reply,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 10),
            Text(
              'Trả lời',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: widget.isPinned ? 'unpin' : 'pin',
        child: Row(
          children: [
            Icon(
              widget.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 10),
            Text(
              widget.isPinned ? 'Bỏ ghim tin nhắn' : 'Ghim tin nhắn',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
      if (widget.message.isText && widget.message.content != null)
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_on_doc,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 10),
              Text(
                'Sao chép',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: menuItems,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
    ).then((value) {
      if (!mounted || value == null) return;
      if (value == 'reply') {
        widget.onSwipeToReply?.call();
      } else if (value == 'pin') {
        widget.onPin?.call();
      } else if (value == 'unpin') {
        widget.onUnpin?.call();
      } else if (value == 'copy') {
        final text = widget.message.content;
        if (text != null) {
          Clipboard.setData(ClipboardData(text: text));
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Đã sao chép tin nhắn vào bộ nhớ tạm'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    });
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

    final hasCaption = message.isImage &&
        message.content != null &&
        message.content != 'Đã gửi một ảnh' &&
        message.content!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _tapped = !_tapped),
            onDoubleTap: widget.onSwipeToReply, // Double tap để reply nhanh
            onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition), // Chuột phải trên Web
            onLongPressStart: (details) => _showContextMenu(context, details.globalPosition), // Nhấn giữ trên Mobile
            child: Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bubble content wrapped in Dismissible for swipe-to-reply (hỗ trợ vuốt cả 2 hướng)
                Flexible(
                  child: SwipeToReply(
                    onReply: () => widget.onSwipeToReply?.call(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.72,
                      ),
                      decoration: BoxDecoration(
                        color: _isHighlighted
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : (message.isImage && !hasCaption
                                ? Colors.transparent
                                : (isMine ? myBubbleColor : theirBubbleColor)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                        // Viền nhấp nháy khi highlight (dùng transparent khi bình thường tránh bị giật layout)
                        border: Border.all(
                          color: _isHighlighted
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nếu có tin nhắn được reply, hiển thị Quote Box giống Zalo
                            if (message.replyToMessage != null)
                              GestureDetector(
                                onTap: () {
                                  if (message.replyToMessageId != null) {
                                    widget.onTapReply?.call(message.replyToMessageId!);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: message.isImage
                                        ? (isMine ? myBubbleColor : theirBubbleColor)
                                        : (isMine
                                            ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.15))
                                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05))),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: message.isImage ? const Radius.circular(12) : Radius.zero,
                                      bottomRight: message.isImage ? const Radius.circular(12) : Radius.zero,
                                    ),
                                  ),
                                  margin: EdgeInsets.only(bottom: message.isImage ? 4 : 0),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        // Cột màu dọc bên trái
                                        Container(
                                          width: 3,
                                          decoration: BoxDecoration(
                                            color: isMine ? Colors.white70 : theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                message.replyToMessage!.senderId == widget.currentUserId
                                                    ? 'Bạn'
                                                    : widget.otherUserName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMine ? Colors.white : theme.colorScheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                message.replyToMessage!.isText
                                                    ? (message.replyToMessage!.content ?? '')
                                                    : (message.replyToMessage!.isImage ? 'Hình ảnh' : 'Cuộc gọi'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isMine ? Colors.white70 : (isDark ? Colors.white70 : Colors.black54),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Thumbnail hình ảnh nhỏ bên phải nếu reply tin nhắn ảnh
                                        if (message.replyToMessage!.isImage && message.replyToMessage!.mediaUrl != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: CachedNetworkImage(
                                                imageUrl: message.replyToMessage!.mediaUrl!,
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => Container(color: Colors.grey.withValues(alpha: 0.2), width: 32, height: 32),
                                                errorWidget: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 16),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Tin nhắn gốc
                            message.isImage && message.mediaUrl != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ImageBubble(
                                        url: message.mediaUrl!,
                                        isMine: isMine,
                                        hasCaption: hasCaption,
                                      ),
                                      if (hasCaption)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          child: Text(
                                            message.content!,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: isMine ? myTextColor : theirTextColor,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                    ],
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
                          ],
                        ),
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
  final bool hasCaption;

  const _ImageBubble({
    required this.url,
    required this.isMine,
    this.hasCaption = false,
  });

  bool get _isLocalPath =>
      !url.startsWith('http') && !url.startsWith('blob');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(hasCaption ? 0 : (isMine ? 18 : 4)),
        bottomRight: Radius.circular(hasCaption ? 0 : (isMine ? 4 : 18)),
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

// ── Custom iOS SwipeToReply Widget (Telegram/Zalo Style) ─────────────────────
class SpringCurve extends Curve {
  final double damping;

  const SpringCurve({this.damping = 0.65});

  @override
  double transformInternal(double t) {
    // Damped harmonic oscillation curve for premium spring bounce back:
    // f(t) = 1 - e^(-5t) * cos(3 * pi * t)
    return 1.0 - math.exp(-5.0 * t) * math.cos(3.0 * math.pi * t);
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _isTriggered = false;

  // Ngưỡng kích hoạt phản hồi
  static const double _triggerThreshold = 55.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // Slightly longer for the springy bounce to resolve nicely
    );
    _controller.addListener(() {
      if (_controller.isAnimating) {
        setState(() {
          _dragOffset = _animation.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    
    setState(() {
      final double delta = details.delta.dx;
      double newOffset = _dragOffset + delta;
      
      // Swipe left only: dragOffset must be <= 0.0
      if (newOffset > 0.0) {
        newOffset = 0.0;
      } else {
        final double absoluteOffset = newOffset.abs();
        if (absoluteOffset > _triggerThreshold) {
          final double excess = absoluteOffset - _triggerThreshold;
          // Apply rubber-band effect (friction decay formula)
          final double rubberBandedExcess = excess / (1.0 + excess * 0.015);
          newOffset = -(_triggerThreshold + rubberBandedExcess);
        }
      }
      
      _dragOffset = newOffset;

      final absoluteOffset = _dragOffset.abs();
      if (absoluteOffset >= _triggerThreshold && !_isTriggered) {
        _isTriggered = true;
        HapticFeedback.mediumImpact(); // Firm, crisp iOS impact vibration
      } else if (absoluteOffset < _triggerThreshold && _isTriggered) {
        _isTriggered = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    if (_dragOffset.abs() >= _triggerThreshold) {
      widget.onReply();
    }

    _isTriggered = false;
    
    // Set up spring-back tween animation
    final double startOffset = _dragOffset;
    _animation = Tween<double>(begin: startOffset, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const SpringCurve(damping: 0.65),
      ),
    );
    
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final absoluteOffset = _dragOffset.abs();
    final progress = (absoluteOffset / _triggerThreshold).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    // Fade in icon as drag progresses
    final iconOpacity = progress.clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Reply Icon (revealed underneath when bubble is pulled left)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: iconOpacity,
                child: AnimatedScale(
                  scale: _isTriggered ? 1.25 : progress,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isTriggered 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: _isTriggered
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Transform.rotate(
                      angle: -progress * 0.25 * math.pi, // Rotate icon up to 45 deg during drag
                      child: Icon(
                        CupertinoIcons.reply,
                        size: 16,
                        color: _isTriggered ? Colors.white : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Dragged chat bubble
          Transform.translate(
            offset: Offset(_dragOffset, 0.0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
