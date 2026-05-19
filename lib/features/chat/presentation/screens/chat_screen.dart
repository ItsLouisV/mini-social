import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/extensions/date_extension.dart';
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMine = message.senderId == currentUserId;
        final isLast = index == messages.length - 1;

        return _MessageBubble(
          message: message,
          isMine: isMine,
          showSeen: isMine && isLast && message.isSeen,
        );
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

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool showSeen;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.showSeen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
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
          Padding(
            padding: EdgeInsets.only(
              top: 4,
              left: isMine ? 0 : 8,
              right: isMine ? 8 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                Text(
                  message.createdAt.chatTimestamp,
                  style: AppTextStyles.caption,
                ),
                if (showSeen) ...[
                  const SizedBox(width: 4),
                  Text('✓✓ Đã xem',
                      style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
