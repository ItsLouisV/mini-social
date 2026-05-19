import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_text_styles.dart';
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
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markAsSeen(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.conversationId, text);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không gửi được: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatMessageGroupTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sixDaysAgo = today.subtract(const Duration(days: 6));

    final dateToCompare = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';

    if (dateToCompare == today) {
      return timeStr;
    } else if (dateToCompare == yesterday) {
      return 'Hôm qua, $timeStr';
    } else if (dateToCompare.isAfter(sixDaysAgo)) {
      const days = [
        'Chủ Nhật',
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy'
      ];
      final index = dateTime.weekday == 7 ? 0 : dateTime.weekday;
      return '${days[index]}, $timeStr';
    } else {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year.toString();
      return '$day/$month/$year, $timeStr';
    }
  }

  Widget _buildTimeDivider(DateTime dateTime) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedStr = _formatMessageGroupTime(dateTime);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            formattedStr,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(realtimeMessagesProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserIdProvider) ?? '';
    final theme = Theme.of(context);

    ref.listen(realtimeMessagesProvider(widget.conversationId), (_, next) {
      next.whenData((_) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      });
    });

    // Lấy tên người dùng từ provider nếu có, fallback về 'Chat'
    final convAsync = ref.watch(conversationsProvider);
    final otherUserName = convAsync.whenData((convs) {
      try {
        final conv = convs.firstWhere((c) => c.id == widget.conversationId);
        return conv.otherUser?.displayName ?? 'Chat';
      } catch (_) {
        return 'Chat';
      }
    }).valueOrNull ?? 'Chat';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.chevron_back,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                'Quay lại',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        middle: Text(
          otherUserName,
          style: TextStyle(
            color: theme.textTheme.titleMedium?.color,
            fontWeight: FontWeight.w600,
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
      return const Center(
        child: Text('Hãy gửi tin nhắn đầu tiên!',
            style: AppTextStyles.bodySmall),
      );
    }

    final listItems = <Widget>[];
    DateTime? lastShowedTime;

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final isMine = message.senderId == currentUserId;
      final isLast = i == messages.length - 1;

      // Nhóm tin nhắn theo khoảng thời gian 10 phút
      if (lastShowedTime == null ||
          message.createdAt.difference(lastShowedTime).inMinutes.abs() >= 10) {
        listItems.add(_buildTimeDivider(message.createdAt));
        lastShowedTime = message.createdAt;
      }

      listItems.add(_MessageBubble(
        key: ValueKey(message.id),
        message: message,
        isMine: isMine,
        showSeen: isMine && isLast && message.isSeen,
      ));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        return listItems[index];
      },
    );
  }

  Widget _buildInput(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Nhắn tin...',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: theme.hintColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                isDense: true,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : const Icon(CupertinoIcons.paperplane_fill,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool showSeen;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSeen = false,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showTime = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = widget.isMine;
    final showSeen = widget.showSeen;
    final message = widget.message;

    final shouldShowTime = _showTime || showSeen;
    final bubbleTimeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showTime = !_showTime;
              });
            },
            child: Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18).copyWith(
                      bottomRight: isMine ? const Radius.circular(4) : null,
                      bottomLeft: !isMine ? const Radius.circular(4) : null,
                    ),
                  ),
                  child: Text(
                    message.content ?? '',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isMine ? Colors.white : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: shouldShowTime
                ? Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      left: isMine ? 0 : 8,
                      right: isMine ? 8 : 0,
                      bottom: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment:
                          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        Text(
                          bubbleTimeStr,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: theme.hintColor,
                          ),
                        ),
                        if (showSeen) ...[
                          const SizedBox(width: 4),
                          Text(
                            '• Đã xem',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
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
