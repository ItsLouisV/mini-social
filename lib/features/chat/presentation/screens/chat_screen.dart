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
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/message_model.dart';
import '../../domain/pinned_message_model.dart';
import '../../providers/chat_provider.dart';

// ── Helper data class ─────────────────────────────────────────────────────────

class _MessageListItem {
  final bool isDivider;
  final DateTime? dateTime;
  final MessageModel? message;
  final bool showInlineTime;
  final bool isLastInGroup;

  const _MessageListItem._({
    required this.isDivider,
    this.dateTime,
    this.message,
    this.showInlineTime = false,
    this.isLastInGroup = true,
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
        isLastInGroup: isLastInGroup,
        showInlineTime: showInlineTime,
      );
}

// ── Grouping helper ───────────────────────────────────────────────────────────

/// Build item list từ messages và trả về đồng thời một map
/// messageId → index trong item list (để scroll chính xác).
///
/// Gọi hàm này bên ngoài build() và cache kết quả để tránh
/// tính lại toàn bộ mỗi khi widget rebuild.
({List<_MessageListItem> items, Map<String, int> indexMap}) _buildItemList(
    List<MessageModel> messages) {
  final items = <_MessageListItem>[];

  // [messages] đang descending (index 0 = mới nhất).
  // ListView reverse: true → item index 0 hiển thị ở đáy.
  // Do đó thứ tự items phải giống messages (descending).

  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];
    // Tin trước đó theo thứ tự thời gian = index i+1 (cũ hơn)
    final olderMsg = i < messages.length - 1 ? messages[i + 1] : null;
    // Tin sau đó theo thứ tự thời gian = index i-1 (mới hơn)
    final newerMsg = i > 0 ? messages[i - 1] : null;

    final isLastInGroup = newerMsg == null ||
        newerMsg.senderId != msg.senderId ||
        newerMsg.createdAt.difference(msg.createdAt).inMinutes.abs() >= 5;

    items.add(_MessageListItem.message(
      msg,
      isLastInGroup: isLastInGroup,
      showInlineTime: isLastInGroup,
    ));

    // Time divider nếu cách tin cũ hơn >= 10 phút, hoặc tin đầu tiên
    if (olderMsg == null ||
        msg.createdAt.difference(olderMsg.createdAt).inMinutes.abs() >= 10) {
      items.add(_MessageListItem.divider(msg.createdAt));
    }
  }

  // Build index map: messageId → index trong items (bỏ qua divider)
  final indexMap = <String, int>{};
  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    if (!item.isDivider && item.message != null) {
      indexMap[item.message!.id] = i;
    }
  }

  return (items: items, indexMap: indexMap);
}

// ── ChatScreen ────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();

  // scrollable_positioned_list controllers — cho phép scroll đến index chính xác
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();

  bool _sending = false;
  XFile? _pendingImage;
  Uint8List? _pendingImagePreviewBytes;
  MessageModel? _replyingToMessage;
  bool _pinnedListExpanded = false;

  // Cache kết quả grouping để không tính lại trong mỗi build()
  List<MessageModel> _cachedMessages = [];
  List<_MessageListItem> _cachedItems = [];
  Map<String, int> _cachedIndexMap = {};

  // ID tin nhắn đang được highlight (sau khi scroll tới)
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markAsSeen(widget.conversationId);
    });

    // Load thêm khi scroll lên đỉnh (tin cũ hơn)
    _itemPositionsListener.itemPositions.addListener(_onPositionChange);
  }

  void _onPositionChange() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Với reverse: true, item có index cao nhất = tin CŨ nhất (hiển thị trên cùng)
    final maxIndex =
        positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final totalItems = _cachedItems.length;

    // Khi gần tới cuối danh sách (đỉnh màn hình với reverse list)
    if (totalItems > 0 && maxIndex >= totalItems - 5) {
      ref
          .read(realtimeMessagesProvider(widget.conversationId).notifier)
          .loadMore();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _itemPositionsListener.itemPositions.removeListener(_onPositionChange);
    super.dispose();
  }

  // ── Cập nhật cache grouping khi messages thay đổi ─────────────────────────

  void _updateCacheIfNeeded(List<MessageModel> messages) {
    // So sánh nhanh bằng length + id đầu + id cuối để tránh rebuild thừa
    if (messages.length == _cachedMessages.length &&
        (messages.isEmpty ||
            (messages.first.id == _cachedMessages.first.id &&
                messages.last.id == _cachedMessages.last.id))) {
      return;
    }
    _cachedMessages = messages;
    final result = _buildItemList(messages);
    _cachedItems = result.items;
    _cachedIndexMap = result.indexMap;
  }

  // ── Scroll tới tin nhắn theo index ────────────────────────────────────────

  void _scrollToBottom({bool animated = true}) {
    if (!_itemScrollController.isAttached) return;
    if (animated) {
      _itemScrollController.scrollTo(
        index: 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _itemScrollController.jumpTo(index: 0);
    }
  }

  /// Scroll tới tin nhắn có [msgId].
  ///
  /// Nếu tin đã có trong state → scroll ngay.
  /// Nếu chưa có → gọi notifier fetch window → notifier set pendingScrollToId
  ///             → _handlePendingScroll sẽ xử lý sau khi rebuild.
  Future<void> _requestScrollToMessage(String msgId) async {
    final notifier =
        ref.read(realtimeMessagesProvider(widget.conversationId).notifier);
    final messagesState =
        ref.read(realtimeMessagesProvider(widget.conversationId)).valueOrNull;

    if (messagesState == null) return;

    final targetMsg =
        messagesState.messages.firstWhere((m) => m.id == msgId, orElse: () {
      // Chưa trong state, cần biết createdAt để fetch window
      // Trường hợp này xảy ra khi gọi từ reply bubble có replyToMessage
      return _emptyMessage;
    });

    if (targetMsg.id.isEmpty) {
      // Không có đủ thông tin → báo user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tìm thấy tin nhắn gốc'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    // Tin đã trong state → scroll trực tiếp
    if (_cachedIndexMap.containsKey(msgId)) {
      _scrollToIndex(_cachedIndexMap[msgId]!, msgId);
    } else {
      // Tin trong state nhưng chưa trong cache (vừa update) → trigger rebuild
      await notifier.jumpToMessage(
        messageId: msgId,
        createdAt: targetMsg.createdAt,
      );
    }
  }

  /// Scroll đến [messageId] từ PinnedMessage (có đủ createdAt).
  Future<void> _jumpToPinnedMessage(PinnedMessageModel pin) async {
    final msgId = pin.messageId;
    final msg = pin.message;
    if (msg == null) return;

    // Kiểm tra đã trong cache chưa
    if (_cachedIndexMap.containsKey(msgId)) {
      _scrollToIndex(_cachedIndexMap[msgId]!, msgId);
      return;
    }

    // Fetch window và để notifier set pendingScrollToId
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            CupertinoActivityIndicator(color: Colors.white),
            SizedBox(width: 12),
            Text('Đang tải tin nhắn...'),
          ]),
          duration: Duration(seconds: 1),
        ),
      );
    }

    await ref
        .read(realtimeMessagesProvider(widget.conversationId).notifier)
        .jumpToMessage(messageId: msgId, createdAt: msg.createdAt);
  }

  /// Thực sự scroll đến [index] và highlight tin [msgId].
  void _scrollToIndex(int index, String msgId) {
    if (!_itemScrollController.isAttached) return;

    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.4, // Hiển thị gần giữa màn hình
    );

    // Highlight sau khi scroll xong
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _highlightedMessageId = msgId);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    });
  }

  /// Xử lý pendingScrollToId từ notifier (sau khi state update + cache rebuild).
  void _handlePendingScroll(String pendingId) {
    // Xoá pending trước để không loop
    ref
        .read(realtimeMessagesProvider(widget.conversationId).notifier)
        .clearPendingScroll();

    final index = _cachedIndexMap[pendingId];
    if (index != null) {
      _scrollToIndex(index, pendingId);
    } else {
      // Vẫn không tìm thấy sau khi fetch → báo user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tin nhắn gốc đã cũ hoặc không tìm thấy'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // ── Gửi tin nhắn ─────────────────────────────────────────────────────────────

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
      _replyingToMessage = null;
    });
    _messageController.clear();

    try {
      if (image != null) {
        await ref.read(chatRepositoryProvider).sendImageMessage(
              widget.conversationId,
              image,
              caption: text.isNotEmpty ? text : null,
              replyToMessageId: replyId,
            );
      } else if (text.isNotEmpty) {
        await ref
            .read(chatRepositoryProvider)
            .sendMessage(widget.conversationId, text,
                replyToMessageId: replyId);
      }

      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      final currentUserId = ref.read(currentUserIdProvider) ?? '';
      try {
        if (image != null) {
          await ref
              .read(realtimeMessagesProvider(widget.conversationId).notifier)
              .addFailedMessage(
                conversationId: widget.conversationId,
                senderId: currentUserId,
                content: text.isNotEmpty ? text : 'Đã gửi một ảnh',
                mediaUrl: image.path,
                messageType: 'image',
                replyToMessageId: replyId,
                replyContent: _replyingToMessage?.content,
                replySenderId: _replyingToMessage?.senderId,
              );
        } else if (text.isNotEmpty) {
          await ref
              .read(realtimeMessagesProvider(widget.conversationId).notifier)
              .addFailedMessage(
                conversationId: widget.conversationId,
                senderId: currentUserId,
                content: text,
                messageType: 'text',
                replyToMessageId: replyId,
                replyContent: _replyingToMessage?.content,
                replySenderId: _replyingToMessage?.senderId,
              );
        }
      } catch (err) {
        debugPrint('Failed to save offline message: $err');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Gửi thất bại. Tin nhắn đã lưu ngoại tuyến.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    Uint8List? previewBytes;
    if (kIsWeb) previewBytes = await picked.readAsBytes();

    setState(() {
      _pendingImage = picked;
      _pendingImagePreviewBytes = previewBytes;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(realtimeMessagesProvider(widget.conversationId));
    final pinnedAsync =
        ref.watch(pinnedMessagesProvider(widget.conversationId));
    final pinnedMessages = pinnedAsync.valueOrNull ?? [];
    final pinnedIds = pinnedMessages.map((pm) => pm.messageId).toSet();
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    final theme = Theme.of(context);

    // Lắng nghe tin mới → auto scroll nếu đang ở đáy
    // Dùng ref.listen ổn định (không đặt inline trong build tree)
    ref.listen(realtimeMessagesProvider(widget.conversationId),
        (previous, next) {
      final prev = previous?.valueOrNull;
      final curr = next.valueOrNull;
      if (curr == null) return;

      // Xử lý pendingScrollToId (từ jumpToMessage)
      if (curr.pendingScrollToId != null) {
        // Đợi cache rebuild xong trong frame này rồi mới scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handlePendingScroll(curr.pendingScrollToId!);
        });
        return;
      }

      // Auto scroll về đáy khi có tin mới (chỉ khi đang gần đáy)
      if (prev != null &&
          curr.messages.isNotEmpty &&
          (prev.messages.isEmpty ||
              curr.messages.first.id != prev.messages.first.id)) {
        final positions = _itemPositionsListener.itemPositions.value;
        final isNearBottom =
            positions.isEmpty || positions.any((p) => p.index == 0);
        if (isNearBottom) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    });

    // Lấy thông tin người kia
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
          IconButton(
            icon: Icon(CupertinoIcons.videocam,
                color: theme.colorScheme.primary, size: 24),
            onPressed: () {
              if (otherUser?.id == null) return;
              context.push('/call/outgoing', extra: {
                'conversationId': widget.conversationId,
                'calleeId': otherUser!.id,
                'calleeName': otherUserName,
                'avatarUrl': otherUser.avatarUrl,
                'isVideo': true,
              });
            },
            tooltip: 'Gọi video',
          ),
          IconButton(
            icon: Icon(CupertinoIcons.phone,
                color: theme.colorScheme.primary, size: 20),
            onPressed: () {
              if (otherUser?.id == null) return;
              context.push('/call/outgoing', extra: {
                'conversationId': widget.conversationId,
                'calleeId': otherUser!.id,
                'calleeName': otherUserName,
                'avatarUrl': otherUser.avatarUrl,
                'isVideo': false,
              });
            },
            tooltip: 'Gọi thoại',
          ),
          IconButton(
            icon: Icon(CupertinoIcons.ellipsis,
                color: theme.colorScheme.primary, size: 20),
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
            if (pinnedMessages.isNotEmpty)
              _buildPinnedMessagesBar(
                  theme, pinnedMessages, currentUserId, otherUserName),
            Expanded(
              child: messagesAsync.when(
                data: (messagesState) {
                  final failedModels = messagesState.failedMessages.map((f) {
                    return MessageModel(
                      id: f.localId,
                      conversationId: f.conversationId,
                      senderId: f.senderId,
                      content: f.content,
                      mediaUrl: f.mediaUrl,
                      messageType: f.messageType,
                      createdAt: DateTime.parse(f.createdAt).toLocal(),
                      replyToMessageId: f.replyToMessageId,
                      replyToMessage: (f.replyToMessageId != null && f.replySenderId != null)
                          ? MessageModel(
                              id: f.replyToMessageId!,
                              conversationId: f.conversationId,
                              senderId: f.replySenderId!,
                              content: f.replyContent,
                              messageType: 'text',
                              createdAt: DateTime.now(),
                            )
                          : null,
                      isFailed: true,
                    );
                  }).toList();

                  final allMessages = [...failedModels, ...messagesState.messages];
                  allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  _updateCacheIfNeeded(allMessages);
                  return _buildMessageList(
                    messagesState,
                    allMessages,
                    currentUserId,
                    otherUserName,
                    pinnedIds,
                  );
                },
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

  // ── Message List ──────────────────────────────────────────────────────────────

  Widget _buildMessageList(
    ChatMessagesState messagesState,
    List<MessageModel> messages,
    String currentUserId,
    String otherUserName,
    Set<String> pinnedIds,
  ) {
    if (_cachedItems.isEmpty) {
      return Center(
        child: Text(
          'Hãy gửi tin nhắn đầu tiên!',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }

    final isMine =
        messages.isNotEmpty && messages.first.senderId == currentUserId;
    final lastIsSeen = messages.isNotEmpty && messages.first.isSeen;

    final isLoadingMore = ref
        .read(realtimeMessagesProvider(widget.conversationId).notifier)
        .isLoadingMore;

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      reverse: true, // index 0 = đáy màn hình = tin mới nhất
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _cachedItems.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Spinner load thêm (hiển thị trên cùng)
        if (index == _cachedItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final item = _cachedItems[index];

        if (item.isDivider) {
          return _TimeDivider(dateTime: item.dateTime!);
        }

        final msg = item.message!;
        final isHighlighted = _highlightedMessageId == msg.id;

        return _MessageBubble(
          key: ValueKey(msg.id), // ValueKey đơn giản, không cần GlobalKey
          message: msg,
          isMine: msg.senderId == currentUserId,
          showInlineTime: item.showInlineTime,
          showSeen: isMine && lastIsSeen && index == 0,
          currentUserId: currentUserId,
          otherUserName: otherUserName,
          isPinned: pinnedIds.contains(msg.id),
          isHighlighted: isHighlighted,
          onPin: () async {
            try {
              await ref
                  .read(chatRepositoryProvider)
                  .pinMessage(widget.conversationId, msg.id);
              ref.invalidate(pinnedMessagesProvider(widget.conversationId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ghim thất bại: $e')),
                );
              }
            }
          },
          onUnpin: () async {
            try {
              await ref
                  .read(chatRepositoryProvider)
                  .unpinMessage(widget.conversationId, msg.id);
              ref.invalidate(pinnedMessagesProvider(widget.conversationId));
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bỏ ghim thất bại: $e')),
                );
              }
            }
          },
          onSwipeToReply: () {
            setState(() {
              _replyingToMessage = msg;
              _focusNode.requestFocus();
            });
          },
          onTapReply: (replyMsgId) {
            // Tìm replyToMessage trong state để có createdAt
            final state = ref
                .read(realtimeMessagesProvider(widget.conversationId))
                .valueOrNull;
            final replyMsg = state?.messages.firstWhere(
              (m) => m.id == replyMsgId,
              orElse: () => msg.replyToMessage ?? _emptyMessage,
            );

            if (replyMsg == null || replyMsg.id.isEmpty) {
              // Không có thông tin → không làm gì
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không thể tìm thấy tin nhắn gốc'),
                  duration: Duration(seconds: 1),
                ),
              );
              return;
            }

            if (_cachedIndexMap.containsKey(replyMsgId)) {
              // Tin đã có trong cache → scroll ngay
              _scrollToIndex(_cachedIndexMap[replyMsgId]!, replyMsgId);
            } else {
              // Chưa load → fetch window
              ref
                  .read(realtimeMessagesProvider(widget.conversationId)
                      .notifier)
                  .jumpToMessage(
                    messageId: replyMsgId,
                    createdAt: replyMsg.createdAt,
                  );
            }
          },
        );
      },
    );
  }

  // ── Pinned Messages Bar ───────────────────────────────────────────────────────

  Widget _buildPinnedMessagesBar(
    ThemeData theme,
    List<PinnedMessageModel> pinnedList,
    String currentUserId,
    String otherUserName,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final latestPin = pinnedList.first;
    final latestMsg = latestPin.message;

    if (latestMsg == null) return const SizedBox.shrink();

    String contentSnippet = latestMsg.isText
        ? (latestMsg.content ?? '')
        : latestMsg.isImage
            ? '[Hình ảnh]'
            : latestMsg.isCall
                ? '[Cuộc gọi]'
                : '[Tin nhắn]';

    final senderName =
        latestMsg.senderId == currentUserId ? 'Bạn' : otherUserName;
    final barBgColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE8F4FD);
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : const Color(0xFF0068FF),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (pinnedList.length > 1) {
              setState(() => _pinnedListExpanded = !_pinnedListExpanded);
            } else {
              _jumpToPinnedMessage(latestPin);
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                if (pinnedList.length > 1)
                  Icon(
                    _pinnedListExpanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: theme.hintColor,
                  )
                else
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .unpinMessage(
                                widget.conversationId, latestPin.messageId);
                        ref.invalidate(
                            pinnedMessagesProvider(widget.conversationId));
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bỏ ghim thất bại: $e')),
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

        // Expanded list khi có nhiều pin
        if (_pinnedListExpanded && pinnedList.length > 1)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: pinnedList.length,
              separatorBuilder: (_, __) => Divider(
                height: 0.5,
                thickness: 0.5,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final pin = pinnedList[index];
                final msg = pin.message;
                if (msg == null) return const SizedBox.shrink();

                final pinSnippet = msg.isText
                    ? (msg.content ?? '')
                    : msg.isImage
                        ? '[Hình ảnh]'
                        : '[Cuộc gọi]';
                final pinSender =
                    msg.senderId == currentUserId ? 'Bạn' : otherUserName;

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
                        color: theme.colorScheme.onSurface),
                  ),
                  onTap: () => _jumpToPinnedMessage(pin),
                  trailing: GestureDetector(
                    onTap: () async {
                      try {
                        await ref
                            .read(chatRepositoryProvider)
                            .unpinMessage(
                                widget.conversationId, pin.messageId);
                        ref.invalidate(
                            pinnedMessagesProvider(widget.conversationId));
                        if (pinnedList.length <= 2) {
                          setState(() => _pinnedListExpanded = false);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Bỏ ghim thất bại: $e')),
                          );
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Icon(
                        CupertinoIcons.trash,
                        size: 14,
                        color:
                            theme.colorScheme.error.withValues(alpha: 0.8),
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

  // ── Image Preview ─────────────────────────────────────────────────────────────

  Widget _buildImagePreview(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final image = _pendingImage!;

    Widget thumbnail;
    if (kIsWeb && _pendingImagePreviewBytes != null) {
      thumbnail = Image.memory(_pendingImagePreviewBytes!,
          width: 72, height: 72, fit: BoxFit.cover);
    } else if (!kIsWeb) {
      thumbnail = Image.file(io.File(image.path),
          width: 72, height: 72, fit: BoxFit.cover);
    } else {
      thumbnail = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFF2F2F7),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: thumbnail),
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
                    child: const Icon(CupertinoIcons.xmark,
                        size: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('1 ảnh đã chọn',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(image.name,
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
    final convAsync = ref.watch(conversationsProvider);
    final otherUser = convAsync
        .whenData((convs) {
          try {
            return convs
                .firstWhere((c) => c.id == widget.conversationId)
                .otherUser;
          } catch (_) {
            return null;
          }
        })
        .valueOrNull;
    final otherUserName = otherUser?.displayName ?? 'Người dùng';

    final msg = _replyingToMessage!;
    final senderName =
        msg.senderId == currentUserId ? 'Bạn' : otherUserName;
    final replyContent = msg.isText
        ? msg.content
        : (msg.isImage ? 'Hình ảnh' : 'Cuộc gọi');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:
            isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
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
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
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
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  replyContent ?? '',
                  style:
                      TextStyle(fontSize: 13, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (msg.isImage && msg.mediaUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: msg.mediaUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      color: Colors.grey.withValues(alpha: 0.2),
                      width: 32,
                      height: 32),
                  errorWidget: (_, __, ___) =>
                      const Icon(CupertinoIcons.photo, size: 16),
                ),
              ),
            ),
          IconButton(
            onPressed: () =>
                setState(() => _replyingToMessage = null),
            icon: const Icon(CupertinoIcons.xmark, size: 16),
            color: theme.hintColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────────

  Widget _buildInput(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final hasPendingImage = _pendingImage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingToMessage != null) _buildReplyPreview(theme),
        if (hasPendingImage) _buildImagePreview(theme),
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
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: hasPendingImage
                          ? 'Thêm chú thích...'
                          : 'Nhắn tin...',
                      hintStyle: TextStyle(
                          color: theme.hintColor, fontSize: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
                          color: bgColor, shape: BoxShape.circle),
                      child: _sending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              ),
                            )
                          : Icon(CupertinoIcons.paperplane_fill,
                              color: iconColor, size: 18),
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
    final dateOnly = DateTime(local.year, local.month, local.day);
    final hhmm = local.localTimeHHmm;

    if (dateOnly == today) return hhmm;
    if (dateOnly == yesterday) return 'Hôm qua, $hhmm';
    if (dateOnly.isAfter(sixDaysAgo)) {
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
    }
    final d = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$d/$mo/${local.year}, $hhmm';
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

class _MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool showInlineTime;
  final bool showSeen;
  final VoidCallback? onSwipeToReply;
  final String currentUserId;
  final String otherUserName;
  final ValueChanged<String>? onTapReply;
  final bool isPinned;
  final bool isHighlighted;
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
    this.isHighlighted = false,
    this.onPin,
    this.onUnpin,
  });

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  bool _tapped = false;

  String get _timeStr {
    final local = widget.message.createdAt.isUtc
        ? widget.message.createdAt.toLocal()
        : widget.message.createdAt;
    return local.localTimeHHmm;
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final messenger = ScaffoldMessenger.of(context);

    final menuItems = <PopupMenuEntry<String>>[
      _buildMenuItem('reply', CupertinoIcons.reply, 'Trả lời', isDark, theme),
      _buildMenuItem(
          widget.isPinned ? 'unpin' : 'pin',
          widget.isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
          widget.isPinned ? 'Bỏ ghim tin nhắn' : 'Ghim tin nhắn',
          isDark,
          theme),
      if (widget.message.isText && widget.message.content != null)
        _buildMenuItem('copy', CupertinoIcons.doc_on_doc, 'Sao chép', isDark,
            theme),
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
      switch (value) {
        case 'reply':
          widget.onSwipeToReply?.call();
        case 'pin':
          widget.onPin?.call();
        case 'unpin':
          widget.onUnpin?.call();
        case 'copy':
          final text = widget.message.content;
          if (text != null) {
            Clipboard.setData(ClipboardData(text: text));
            messenger.showSnackBar(const SnackBar(
              content: Text('Đã sao chép tin nhắn vào bộ nhớ tạm'),
              duration: Duration(seconds: 1),
            ));
          }
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem(
      String value, IconData icon, String label, bool isDark, ThemeData theme) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: isDark ? Colors.white70 : Colors.black87),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  void _showFailedMessageMenu(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Tin nhắn chưa được gửi'),
        message: const Text('Có lỗi xảy ra khi gửi tin nhắn này. Bạn có muốn gửi lại không?'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(realtimeMessagesProvider(widget.message.conversationId)
                      .notifier)
                  .retryFailedMessage(widget.message.id);
            },
            child: const Text('Gửi lại'),
          ),
          if (widget.message.isText && widget.message.content != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: widget.message.content!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Đã sao chép tin nhắn vào bộ nhớ tạm'),
                  duration: Duration(seconds: 1),
                ));
              },
              child: const Text('Sao chép'),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(realtimeMessagesProvider(widget.message.conversationId)
                      .notifier)
                  .removeFailedMessage(widget.message.id);
            },
            child: const Text('Xoá'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMine = widget.isMine;
    final message = widget.message;
    final isHighlighted = widget.isHighlighted;

    final myBubbleColor =
        isDark ? AppColors.darkChatBubbleSender : AppColors.chatBubbleSender;
    final theirBubbleColor = isDark
        ? AppColors.darkChatBubbleReceiver
        : AppColors.chatBubbleReceiver;
    final myTextColor =
        isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender;
    final theirTextColor = isDark
        ? AppColors.darkChatTextReceiver
        : AppColors.chatTextReceiver;

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
            onTap: () {
              if (message.isFailed) {
                _showFailedMessageMenu(context);
              } else {
                setState(() => _tapped = !_tapped);
              }
            },
            onDoubleTap: message.isFailed ? null : widget.onSwipeToReply,
            onSecondaryTapDown: (d) {
              if (message.isFailed) {
                _showFailedMessageMenu(context);
              } else {
                _showContextMenu(context, d.globalPosition);
              }
            },
            onLongPressStart: (d) {
              if (message.isFailed) {
                _showFailedMessageMenu(context);
              } else {
                _showContextMenu(context, d.globalPosition);
              }
            },
            child: Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isMine && message.isFailed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: GestureDetector(
                      onTap: () => _showFailedMessageMenu(context),
                      child: const Icon(
                        CupertinoIcons.exclamationmark_circle_fill,
                        color: CupertinoColors.systemRed,
                        size: 22,
                      ),
                    ),
                  ),
                Flexible(
                  child: SwipeToReply(
                    enabled: !message.isFailed,
                    onReply: () => widget.onSwipeToReply?.call(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? theme.colorScheme.primary
                                .withValues(alpha: 0.25)
                            : (message.isImage && !hasCaption
                                ? Colors.transparent
                                : (isMine
                                    ? myBubbleColor
                                    : theirBubbleColor)),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                        border: Border.all(
                          color: isHighlighted
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
                            // Quote box (reply preview bên trong bubble)
                            if (message.replyToMessage != null)
                              GestureDetector(
                                onTap: () {
                                  if (message.replyToMessageId != null) {
                                    widget.onTapReply
                                        ?.call(message.replyToMessageId!);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: message.isImage
                                        ? (isMine
                                            ? myBubbleColor
                                            : theirBubbleColor)
                                        : (isMine
                                            ? (isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.12)
                                                : Colors.black
                                                    .withValues(alpha: 0.15))
                                            : (isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.08)
                                                : Colors.black
                                                    .withValues(alpha: 0.05))),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: message.isImage
                                          ? const Radius.circular(12)
                                          : Radius.zero,
                                      bottomRight: message.isImage
                                          ? const Radius.circular(12)
                                          : Radius.zero,
                                    ),
                                  ),
                                  margin: EdgeInsets.only(
                                      bottom: message.isImage ? 4 : 0),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 3,
                                          decoration: BoxDecoration(
                                            color: isMine
                                                ? Colors.white70
                                                : theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                message.replyToMessage!
                                                            .senderId ==
                                                        widget.currentUserId
                                                    ? 'Bạn'
                                                    : widget.otherUserName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isMine
                                                      ? Colors.white
                                                      : theme.colorScheme
                                                          .primary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                message.replyToMessage!.isText
                                                    ? (message.replyToMessage!
                                                            .content ??
                                                        '')
                                                    : (message.replyToMessage!
                                                            .isImage
                                                        ? 'Hình ảnh'
                                                        : 'Cuộc gọi'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isMine
                                                      ? Colors.white70
                                                      : (isDark
                                                          ? Colors.white70
                                                          : Colors.black54),
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (message.replyToMessage!.isImage &&
                                            message.replyToMessage!.mediaUrl !=
                                                null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 8),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: CachedNetworkImage(
                                                imageUrl: message
                                                    .replyToMessage!.mediaUrl!,
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) =>
                                                    Container(
                                                  color: Colors.grey
                                                      .withValues(alpha: 0.2),
                                                  width: 32,
                                                  height: 32,
                                                ),
                                                errorWidget: (_, __, ___) =>
                                                    const Icon(
                                                        CupertinoIcons.photo,
                                                        size: 16),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Nội dung tin nhắn
                            if (message.isImage && message.mediaUrl != null)
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                          color: isMine
                                              ? myTextColor
                                              : theirTextColor,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            else if (message.isCall)
                              _CallLogBubble(
                                  message: message, isMine: isMine)
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Text(
                                  message.content ?? '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: isMine
                                        ? myTextColor
                                        : theirTextColor,
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

          // Time + seen indicator
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
                              fontSize: 10, color: theme.hintColor),
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
        bottomLeft:
            Radius.circular(hasCaption ? 0 : (isMine ? 18 : 4)),
        bottomRight:
            Radius.circular(hasCaption ? 0 : (isMine ? 4 : 18)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 300,
        ),
        child: _isLocalPath && !kIsWeb
            ? Image.file(io.File(url), fit: BoxFit.cover)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 200,
                  height: 160,
                  color: Colors.grey.withValues(alpha: 0.2),
                  child:
                      const Center(child: CupertinoActivityIndicator()),
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
        : (isDark
            ? AppColors.darkChatTextReceiver
            : AppColors.chatTextReceiver);

    final content = message.content ?? '';
    final isMissed = content.toLowerCase().contains('nhỡ') ||
        content.toLowerCase().contains('từ chối') ||
        content.toLowerCase().contains('đã hủy');
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
              color: isMine
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo
                  ? CupertinoIcons.videocam_fill
                  : CupertinoIcons.phone_fill,
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

// ── SwipeToReply ──────────────────────────────────────────────────────────────

class SpringCurve extends Curve {
  final double damping;
  const SpringCurve({this.damping = 0.65});

  @override
  double transformInternal(double t) {
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

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _isTriggered = false;
  static const double _triggerThreshold = 55.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _controller.addListener(() {
      if (_controller.isAnimating) {
        setState(() => _dragOffset = _animation.value);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails _) => _controller.stop();

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      double newOffset = _dragOffset + details.delta.dx;
      if (newOffset > 0.0) {
        newOffset = 0.0;
      } else {
        final abs = newOffset.abs();
        if (abs > _triggerThreshold) {
          final excess = abs - _triggerThreshold;
          newOffset = -(_triggerThreshold + excess / (1.0 + excess * 0.015));
        }
      }
      _dragOffset = newOffset;

      if (_dragOffset.abs() >= _triggerThreshold && !_isTriggered) {
        _isTriggered = true;
        HapticFeedback.mediumImpact();
      } else if (_dragOffset.abs() < _triggerThreshold && _isTriggered) {
        _isTriggered = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (!widget.enabled) return;
    if (_dragOffset.abs() >= _triggerThreshold) widget.onReply();
    _isTriggered = false;
    final start = _dragOffset;
    _animation = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(
          parent: _controller, curve: const SpringCurve(damping: 0.65)),
    );
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Opacity(
                opacity: progress,
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
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.25),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Transform.rotate(
                      angle: -progress * 0.25 * math.pi,
                      child: Icon(
                        CupertinoIcons.reply,
                        size: 16,
                        color: _isTriggered
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dragOffset, 0.0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ── MessageModel sentinel ─────────────────────────────────────────────────────
// Dùng làm giá trị mặc định khi firstWhere không tìm thấy, tránh Exception.
// Kiểm tra bằng: sentinel.id.isEmpty

MessageModel get _emptyMessage => MessageModel(
  id: '',
  conversationId: '',
  senderId: '',
  createdAt: DateTime.utc(1970),
);