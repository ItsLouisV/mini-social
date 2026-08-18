import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../social/data/ai_repository.dart';
import '../../domain/message_model.dart';
import '../../domain/conversation_member_model.dart';
import '../../providers/chat_provider.dart';
import '../../../../shared/widgets/app_avatar.dart';
import 'full_screen_image_viewer.dart';
import 'message_context_menu_route.dart';
import 'expandable_message_text.dart';
import 'message_popup_menu_content.dart';
import 'voice_message_bubble.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;
  final bool showSenderInfo;
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
  final Function(MessageModel)? onRetrySend;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isGroup = false,
    this.showSenderInfo = true,
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
    this.onRetrySend,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _tapped = false;
  bool _isMessageExpanded = false;
  final GlobalKey _bubbleKey = GlobalKey();

  // Translation state
  String? _translatedText;
  bool _isTranslating = false;
  bool _showTranslation = false;

  Future<void> _translateMessage() async {
    final content = widget.message.content?.trim();

    if (content == null || content.isEmpty || _isTranslating) {
      return;
    }

    if (_translatedText != null) {
      setState(() {
        _showTranslation = !_showTranslation;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      final currentLanguage = ref.read(appLanguageProvider);
      final targetLanguage = currentLanguage == AppLanguage.en ? 'en' : 'vi';
      final aiRepository = ref.read(aiRepositoryProvider);

      final translatedText = await aiRepository.translateText(
        content,
        targetLanguage: targetLanguage,
      );

      if (!mounted) return;

      setState(() {
        _translatedText = translatedText;
        _showTranslation = true;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể dịch tin nhắn này'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  void _showMessageReportDialog(MessageModel message) {
    String selectedReason = 'Spam / Phền phức';
    final customReasonController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text('Báo cáo tin nhắn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Vui lòng chọn lý do báo cáo tin nhắn này:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...[
                'Spam / Phền phức',
                'Nội dung đồi truỵ / Khiêu dâm',
                'Quấy rối / Lừa đảo',
                'Bạo lực / Thù ghét',
                'Lý do khác...',
              ].map((reason) => GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedReason = reason;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == reason
                                ? CupertinoIcons.checkmark_alt_circle_fill
                                : CupertinoIcons.circle,
                            size: 18,
                            color: selectedReason == reason
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
              if (selectedReason == 'Lý do khác...') ...[
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: customReasonController,
                  placeholder: 'Nhập lý do báo cáo...',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Hủy'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Gửi báo cáo'),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã gửi báo cáo. Cảm ơn bạn!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();

    final RenderBox renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    final message = widget.message;
    final isMine = widget.isMine;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[message.conversationId] ?? 'blue';
    final myBubbleColor = getChatThemeColor(themeName, isDark: isDark);
    final theirBubbleColor = isDark
        ? AppColors.darkChatBubbleReceiver
        : AppColors.chatBubbleReceiver;
    final myTextColor = (themeName == 'blue')
        ? (isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender)
        : Colors.white;
    final theirTextColor =
        isDark ? AppColors.darkChatTextReceiver : AppColors.chatTextReceiver;

    final hasCaption = message.isImage &&
        message.content != null &&
        message.content != 'Đã gửi một ảnh' &&
        message.content!.trim().isNotEmpty;

    final overlayBubbleWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: message.isImage && !hasCaption
            ? Colors.transparent
            : (isMine ? myBubbleColor : theirBubbleColor),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToMessage != null)
              Container(
                decoration: BoxDecoration(
                  color: message.isImage
                      ? (isMine ? myBubbleColor : theirBubbleColor)
                      : (isMine
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.15))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05))),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: message.isImage
                        ? const Radius.circular(10)
                        : Radius.zero,
                    bottomRight: message.isImage
                        ? const Radius.circular(10)
                        : Radius.zero,
                  ),
                ),
                margin: EdgeInsets.only(bottom: message.isImage ? 4 : 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.white70
                              : theme.colorScheme.primary,
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
                              () {
                                if (message.replyToMessage!.senderId ==
                                    widget.currentUserId) return 'Bạn';
                                final replyProfile = ref
                                    .watch(profileProvider(
                                        message.replyToMessage!.senderId))
                                    .valueOrNull;
                                return replyProfile?.displayName ??
                                    replyProfile?.fullName ??
                                    (widget.isGroup
                                        ? 'Thành viên'
                                        : widget.otherUserName);
                              }(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMine
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.replyToMessage!.isText
                                  ? (message.replyToMessage!.content ?? '')
                                  : (message.replyToMessage!.isVoice
                                      ? 'Tin nhắn thoại'
                                      : (message.replyToMessage!.isImage
                                          ? 'Hình ảnh'
                                          : 'Cuộc gọi')),
                              style: TextStyle(
                                fontSize: 12,
                                color: isMine
                                    ? Colors.white70
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black54),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (message.isImage && message.firstMediaUrl != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ImageBubble(
                    url: message.firstMediaUrl!,
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
            else
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExpandableMessageText(
                      text: message.content ?? '',
                      expanded: _isMessageExpanded,
                      onToggle: () => setState(
                        () => _isMessageExpanded = !_isMessageExpanded,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        color: isMine ? myTextColor : theirTextColor,
                        height: 1.35,
                      ),
                    ),
                    if (_isTranslating || _showTranslation) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.16)
                              : getChatThemePrimaryColor(themeName)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isTranslating
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 11,
                                    height: 11,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: isMine
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : getChatThemePrimaryColor(themeName),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Đang dịch...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: isMine
                                          ? Colors.white.withValues(alpha: 0.75)
                                          : theme.hintColor,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FaIcon(
                                    FontAwesomeIcons.language,
                                    size: 13,
                                    color: (isMine
                                            ? Colors.white
                                            : getChatThemePrimaryColor(
                                                themeName))
                                        .withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _translatedText ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
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
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    Navigator.push(
      context,
      MessageContextMenuRoute(
        messagePosition: position,
        messageSize: size,
        messageWidget: overlayBubbleWidget,
        isMine: isMine,
        keepAnchorVisible: true,
        backdropOpacity: 0.72,
        anchorMenuGap: 28,
        estimatedMenuHeight: 350,
        allowScaleOvershoot: false,
        menuContentWidget: MessagePopupMenuContent(
          isMine: isMine,
          isPinned: widget.isPinned,
          isText: message.isText,
          isRecalled: message.isRecalled,
          hasMyReaction: message.reactions.values
              .any((users) => users.contains(widget.currentUserId)),
          onClearAllReactions: () {
            Navigator.pop(context);
            ref
                .read(realtimeMessagesProvider(message.conversationId).notifier)
                .clearMyReactions(message.id);
          },
          onReply: () {
            Navigator.pop(context);
            widget.onSwipeToReply?.call();
          },
          onCopy: message.isText && message.content != null
              ? () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Đã sao chép tin nhắn vào bộ nhớ tạm'),
                    duration: Duration(seconds: 1),
                  ));
                }
              : () {},
          onForward: () {},
          onPin: widget.onPin ?? () {},
          onUnpin: widget.onUnpin ?? () {},
          onRecall: isMine
              ? () {
                  Navigator.pop(context);
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('Thu hồi tin nhắn'),
                      content: const Text(
                          'Tin nhắn này sẽ bị thu hồi đối với tất cả mọi người trong cuộc trò chuyện. Bạn có chắc chắn?'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Huỷ'),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: const Text('Thu hồi'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref
                                .read(realtimeMessagesProvider(
                                        message.conversationId)
                                    .notifier)
                                .recallMessage(message.id);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('Đã thu hồi tin nhắn'),
                              duration: Duration(seconds: 1),
                            ));
                          },
                        ),
                      ],
                    ),
                  );
                }
              : null,
          onDelete: () {
            Navigator.pop(context);
            final permissions = widget.isGroup
                ? ref.read(groupPermissionsProvider(message.conversationId))
                : null;
            final senderMember = widget.isGroup
                ? ref
                    .read(groupMembersProvider(message.conversationId))
                    .valueOrNull
                    ?.where((member) => member.userId == message.senderId)
                    .firstOrNull
                : null;
            final deletePermanently = message.isRecalled ||
                (message.senderId != widget.currentUserId &&
                    (permissions?.isAdmin ?? false) &&
                    (senderMember?.isMember ?? false));
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Xóa tin nhắn'),
                content: Text(deletePermanently
                    ? 'Tin nhắn này sẽ bị xóa vĩnh viễn khỏi cuộc trò chuyện.'
                    : 'Tin nhắn này chỉ bị xóa ở phía bạn. Những người khác vẫn nhìn thấy tin nhắn.'),
                actions: [
                  CupertinoDialogAction(
                    child: const Text('Huỷ'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: const Text('Xóa'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final notifier = ref.read(
                          realtimeMessagesProvider(message.conversationId)
                              .notifier);
                      if (deletePermanently) {
                        await notifier.deleteMessage(message.id);
                      } else {
                        await notifier.deleteMessageLocally(message.id);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(deletePermanently
                            ? 'Đã xóa tin nhắn vĩnh viễn'
                            : 'Đã xóa tin nhắn phía bạn'),
                        duration: Duration(seconds: 1),
                      ));
                    },
                  ),
                ],
              ),
            );
          },
          onInfo: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Gửi lúc: ${message.createdAt.toLocal().toString()}'),
              duration: const Duration(seconds: 2),
            ));
          },
          onReact: (emoji) {
            Navigator.pop(context);
            ref
                .read(realtimeMessagesProvider(message.conversationId).notifier)
                .toggleReaction(message.id, emoji);
          },
          onTranslate: message.isText
              ? () {
                  Navigator.pop(context);
                  if (_showTranslation) {
                    setState(() => _showTranslation = false);
                  } else {
                    _translateMessage();
                  }
                }
              : null,
          isTranslationShown: _showTranslation,
          onReport: () {
            Navigator.pop(context);
            _showMessageReportDialog(message);
          },
        ),
      ),
    );
  }

  String get _timeStr {
    final local = widget.message.createdAt.isUtc
        ? widget.message.createdAt.toLocal()
        : widget.message.createdAt;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showReactionsBottomSheet(BuildContext context, MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _ReactionsBottomSheet(
          message: message,
          currentUserId: widget.currentUserId,
        );
      },
    );
  }

  void _showFailedMessageMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text(
          'Tin nhắn chưa được gửi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
              'Có lỗi xảy ra khi gửi tin nhắn này. Bạn có muốn thử lại không?'),
        ),
        actions: [
          CupertinoDialogAction(
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
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onRetrySend != null) {
                widget.onRetrySend!(widget.message);
              } else {
                ref
                    .read(
                        realtimeMessagesProvider(widget.message.conversationId)
                            .notifier)
                    .retryFailedMessage(widget.message.id);
              }
            },
            child: const Text('Thử lại'),
          ),
        ],
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

    final senderProfile = (!isMine && widget.isGroup && widget.showSenderInfo)
        ? ref.watch(profileProvider(message.senderId)).valueOrNull
        : null;
    final senderName = senderProfile?.displayName ??
        senderProfile?.fullName ??
        widget.otherUserName;
    final senderAvatarUrl = senderProfile?.avatarUrl;

    final groupMembers = (!isMine && widget.isGroup)
        ? ref.watch(groupMembersProvider(message.conversationId)).valueOrNull
        : null;
    final senderMember = groupMembers?.firstWhere(
      (m) => m.userId == message.senderId,
      orElse: () => ConversationMemberModel(
        id: '',
        conversationId: message.conversationId,
        userId: message.senderId,
      ),
    );

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[message.conversationId] ?? 'blue';
    final replyThemeColor = getChatThemePrimaryColor(themeName);

    Color senderNameColor = replyThemeColor;
    Widget? roleBadge;
    if (senderMember != null) {
      if (senderMember.isOwner) {
        senderNameColor = const Color(0xFFFF9500);
        roleBadge = const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('👑', style: TextStyle(fontSize: 10)),
        );
      } else if (senderMember.isCoAdmin) {
        senderNameColor = const Color(0xFF5856D6);
        roleBadge = const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('⭐', style: TextStyle(fontSize: 10)),
        );
      }
    }

    final myBubbleColor = getChatThemeColor(themeName, isDark: isDark);
    final theirBubbleColor = isDark
        ? AppColors.darkChatBubbleReceiver
        : AppColors.chatBubbleReceiver;
    final myTextColor = (themeName == 'blue')
        ? (isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender)
        : Colors.white;
    final theirTextColor =
        isDark ? AppColors.darkChatTextReceiver : AppColors.chatTextReceiver;

    final showTime = _tapped ||
        widget.showInlineTime ||
        (isMine && (message.isSending || message.isFailed));

    final hasCaption = message.isImage &&
        message.content != null &&
        message.content != 'Đã gửi một ảnh' &&
        message.content!.trim().isNotEmpty;

    Widget bubbleContent = SwipeToReply(
      key: _bubbleKey,
      enabled: !message.isFailed && !message.isRecalled && !message.isSending,
      replyThemeColor: replyThemeColor,
      onReply: () => widget.onSwipeToReply?.call(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: message.isRecalled
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1))
              : (isHighlighted
                  ? theme.colorScheme.primary.withValues(alpha: 0.25)
                  : (message.isImage && !hasCaption
                      ? Colors.transparent
                      : (isMine ? myBubbleColor : theirBubbleColor))),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isHighlighted ? theme.colorScheme.primary : Colors.transparent,
            width: isHighlighted ? 1.5 : 0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMine && widget.isGroup && widget.showSenderInfo)
                Padding(
                  padding: const EdgeInsets.only(
                      left: 14, right: 14, top: 8, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: senderNameColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (roleBadge != null) roleBadge,
                    ],
                  ),
                ),
              if (message.replyToMessage != null)
                Container(
                  decoration: BoxDecoration(
                    color: message.isImage
                        ? (isMine ? myBubbleColor : theirBubbleColor)
                        : (isMine
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.15))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05))),
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
                  margin: EdgeInsets.only(bottom: message.isImage ? 4 : 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white70
                                : theme.colorScheme.primary,
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
                                () {
                                  if (message.replyToMessage!.senderId ==
                                      widget.currentUserId) return 'Bạn';
                                  final replyProfile = ref
                                      .watch(profileProvider(
                                          message.replyToMessage!.senderId))
                                      .valueOrNull;
                                  return replyProfile?.displayName ??
                                      replyProfile?.fullName ??
                                      (widget.isGroup
                                          ? 'Thành viên'
                                          : widget.otherUserName);
                                }(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMine
                                      ? Colors.white
                                      : theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.replyToMessage!.isText
                                    ? (message.replyToMessage!.content ?? '')
                                    : (message.replyToMessage!.isVoice
                                        ? 'Tin nhắn thoại'
                                        : (message.replyToMessage!.isImage
                                            ? 'Hình ảnh'
                                            : 'Cuộc gọi')),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMine
                                      ? Colors.white70
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black54),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (message.replyToMessage!.isImage &&
                            message.replyToMessage!.firstMediaUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl:
                                    message.replyToMessage!.firstMediaUrl!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  width: 32,
                                  height: 32,
                                ),
                                errorWidget: (_, __, ___) =>
                                    const Icon(CupertinoIcons.photo, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Nội dung tin nhắn
              if (message.isRecalled)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    'Tin nhắn đã được thu hồi',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                )
              else if (message.isImage && message.firstMediaUrl != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ImageBubble(
                      url: message.firstMediaUrl!,
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
              else if (message.isCall)
                _CallLogBubble(message: message, isMine: isMine)
              else if (message.isVoice && message.firstMediaUrl != null)
                VoiceMessageBubble(
                  audioUrl: message.firstMediaUrl!,
                  isMe: isMine,
                  themeColor: getChatThemePrimaryColor(themeName),
                  contentLabel: message.content,
                )
              else
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExpandableMessageText(
                        text: message.content ?? '',
                        expanded: _isMessageExpanded,
                        onToggle: () => setState(
                          () => _isMessageExpanded = !_isMessageExpanded,
                        ),
                        style: TextStyle(
                          fontSize: 15,
                          color: isMine ? myTextColor : theirTextColor,
                          height: 1.35,
                        ),
                      ),
                      // Bản dịch AI
                      if (_isTranslating || _showTranslation) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.16)
                                : getChatThemePrimaryColor(themeName)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isTranslating
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 11,
                                      height: 11,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: isMine
                                            ? Colors.white
                                                .withValues(alpha: 0.7)
                                            : getChatThemePrimaryColor(
                                                themeName),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      'Đang dịch...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: isMine
                                            ? Colors.white
                                                .withValues(alpha: 0.75)
                                            : theme.hintColor,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.language,
                                      size: 13,
                                      color: (isMine
                                              ? Colors.white
                                              : getChatThemePrimaryColor(
                                                  themeName))
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _translatedText ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
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
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final hasReactions = message.hasReactions;
    bubbleContent = Flexible(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          bubbleContent,
          if (hasReactions)
            Positioned(
              bottom: -15,
              right: isMine ? 28 : null,
              left: isMine ? null : 33,
              child: _ReactionBar(
                reactions: message.reactions,
                currentUserId: widget.currentUserId,
                isMine: isMine,
                onTap: () => _showReactionsBottomSheet(context, message),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: hasReactions ? 16 : 2),
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
            onDoubleTap:
                message.isFailed || message.isRecalled || message.isSending
                    ? null
                    : widget.onSwipeToReply,
            onSecondaryTapDown: message.isFailed || message.isSending
                ? (message.isFailed
                    ? (d) => _showFailedMessageMenu(context)
                    : null)
                : (d) => _showCustomContextMenu(context),
            onLongPressStart: message.isFailed || message.isSending
                ? (message.isFailed
                    ? (d) => _showFailedMessageMenu(context)
                    : null)
                : (d) => _showCustomContextMenu(context),
            child: Row(
              mainAxisAlignment:
                  isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMine && widget.isGroup) ...[
                  if (widget.showSenderInfo)
                    AppAvatar(
                      imageUrl: senderAvatarUrl,
                      name: senderName,
                      radius: 14,
                    )
                  else
                    const SizedBox(width: 28),
                  const SizedBox(width: 6),
                ],
                if (message.isVanish && isMine) ...[
                  _VanishTimerIndicator(
                    message: message,
                    onExpired: () {
                      ref
                          .read(realtimeMessagesProvider(message.conversationId)
                              .notifier)
                          .deleteMessage(message.id);
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                bubbleContent,
                if (isMine && message.isFailed)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => _showFailedMessageMenu(context),
                      child: const Icon(
                        CupertinoIcons.exclamationmark_circle_fill,
                        color: CupertinoColors.systemRed,
                        size: 22,
                      ),
                    ),
                  ),
                if (message.isVanish && !isMine) ...[
                  const SizedBox(width: 6),
                  _VanishTimerIndicator(
                    message: message,
                    onExpired: () {
                      ref
                          .read(realtimeMessagesProvider(message.conversationId)
                              .notifier)
                          .deleteMessage(message.id);
                    },
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: showTime
                ? Padding(
                    padding: EdgeInsets.only(
                      top: 3,
                      bottom: 4,
                      left: isMine ? 0 : (widget.isGroup ? 40 : 6),
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
                          style:
                              TextStyle(fontSize: 10, color: theme.hintColor),
                        ),
                        if (isMine) ...[
                          if (message.isSending) ...[
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.2,
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• Đang gửi...',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.hintColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ] else if (message.isFailed) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '• Chưa gửi được',
                              style: TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.systemRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else if (widget.showSeen || message.isSeen) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• Đã xem',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 4),
                            Text(
                              '• Đã gửi',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
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

class _ReactionBar extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final bool isMine;
  final VoidCallback onTap;

  const _ReactionBar({
    required this.reactions,
    required this.currentUserId,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeReactions =
        reactions.entries.where((entry) => entry.value.isNotEmpty).toList();

    if (activeReactions.isEmpty) return const SizedBox.shrink();

    activeReactions.sort((a, b) => b.value.length.compareTo(a.value.length));
    final topReactions = activeReactions.take(2).toList();
    final totalCount =
        activeReactions.fold<int>(0, (sum, entry) => sum + entry.value.length);
    final iReacted =
        activeReactions.any((entry) => entry.value.contains(currentUserId));

    final pillBgColor = iReacted
        ? (isDark ? const Color(0xFF1B3D6D) : const Color(0xFFD0ECFC))
        : (isDark ? const Color(0xFF2E2E3E) : const Color(0xFFEBEBEB));

    final pillBorderColor = iReacted
        ? (isDark
            ? Colors.blue.withValues(alpha: 0.5)
            : Colors.blue.withValues(alpha: 0.3))
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));

    final List<Widget> emojiWidgets = [];
    for (int i = 0; i < topReactions.length; i++) {
      emojiWidgets.add(
        Positioned(
          left: i * 11.0,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pillBgColor,
            ),
            alignment: Alignment.center,
            child: Text(
              topReactions[i].key,
              style: const TextStyle(
                fontSize: 12,
                height: 1.0,
                fontFamilyFallback: [
                  'Apple Color Emoji',
                  'Segoe UI Emoji',
                  'Noto Color Emoji'
                ],
              ),
            ),
          ),
        ),
      );
    }

    final emojiStackWidth = topReactions.length == 1 ? 18.0 : 29.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: pillBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: pillBorderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: emojiStackWidth,
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: emojiWidgets,
              ),
            ),
            if (totalCount > 1) ...[
              const SizedBox(width: 4),
              Text(
                '$totalCount',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: iReacted
                      ? Colors.blue
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final String url;
  final bool isMine;
  final bool hasCaption;

  const _ImageBubble({
    required this.url,
    required this.isMine,
    this.hasCaption = false,
  });

  bool get _isLocalPath => !url.startsWith('http') && !url.startsWith('blob');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FullScreenImageViewer.open(context, url),
      child: Hero(
        tag: url,
        child: ClipRRect(
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
                ? Image.file(io.File(url), fit: BoxFit.cover)
                : (kIsWeb
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 160,
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Icon(CupertinoIcons.photo, color: Colors.grey),
                        ),
                        loadingBuilder: (_, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 200,
                            height: 160,
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: const Center(child: CupertinoActivityIndicator()),
                          );
                        },
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 200,
                          height: 160,
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Center(child: CupertinoActivityIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 200,
                          height: 160,
                          color: Colors.grey.withValues(alpha: 0.2),
                          child: const Icon(CupertinoIcons.photo, color: Colors.grey),
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}

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

    final missedColor =
        isMine ? const Color(0xFFFFB2B2) : const Color(0xFFFF2D55);
    final color = isMissed ? missedColor : textColor;

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
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

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
  final Color replyThemeColor;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
    required this.replyThemeColor,
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
        HapticFeedback.lightImpact();
      } else if (_dragOffset.abs() < _triggerThreshold && _isTriggered) {
        _isTriggered = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (!widget.enabled) return;
    if (_dragOffset.abs() >= _triggerThreshold) {
      HapticFeedback.mediumImpact();
      widget.onReply();
    }
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
    final progress = (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);
    final replyThemeColor = widget.replyThemeColor;

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
                          ? replyThemeColor
                          : replyThemeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      boxShadow: _isTriggered
                          ? [
                              BoxShadow(
                                color: replyThemeColor.withValues(alpha: 0.25),
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
                        color: _isTriggered ? Colors.white : replyThemeColor,
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

class _ReactionsBottomSheet extends ConsumerStatefulWidget {
  final MessageModel message;
  final String currentUserId;

  const _ReactionsBottomSheet({
    required this.message,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ReactionsBottomSheet> createState() =>
      _ReactionsBottomSheetState();
}

class _ReactionsBottomSheetState extends ConsumerState<_ReactionsBottomSheet> {
  String _selectedTab = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeReactions = widget.message.reactions.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    activeReactions.sort((a, b) => b.value.length.compareTo(a.value.length));
    final totalCount =
        activeReactions.fold<int>(0, (sum, entry) => sum + entry.value.length);

    final List<({String id, String label, int count})> tabs = [
      (id: 'all', label: 'Tất cả', count: totalCount),
      ...activeReactions.map((entry) =>
          (id: entry.key, label: entry.key, count: entry.value.length)),
    ];

    final List<({String userId, String emoji})> items = [];
    if (_selectedTab == 'all') {
      for (final entry in activeReactions) {
        for (final userId in entry.value) {
          items.add((userId: userId, emoji: entry.key));
        }
      }
    } else {
      final entry = activeReactions.firstWhere((e) => e.key == _selectedTab,
          orElse: () => activeReactions.first);
      for (final userId in entry.value) {
        items.add((userId: userId, emoji: entry.key));
      }
    }

    final List<Widget> listChildren = [
      const SizedBox(height: 10),
      Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white30 : Colors.black26,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Center(
        child: Text(
          'Biểu cảm',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedTab == tab.id;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTab = tab.id);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white10 : Colors.black12),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tab.count}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 10),
      const Divider(height: 1),
      Flexible(
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final profileAsync = ref.watch(profileProvider(item.userId));
            final profile = profileAsync.valueOrNull;

            final displayName = item.userId == widget.currentUserId
                ? 'Bạn'
                : (profile?.displayName ?? 'Người dùng');
            final avatarUrl = profile?.avatarUrl;

            return ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                item.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            );
          },
        ),
      ),
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: listChildren,
        ),
      ),
    );
  }
}

class _VanishTimerIndicator extends StatefulWidget {
  final MessageModel message;
  final VoidCallback onExpired;

  const _VanishTimerIndicator({
    required this.message,
    required this.onExpired,
  });

  @override
  State<_VanishTimerIndicator> createState() => _VanishTimerIndicatorState();
}

class _VanishTimerIndicatorState extends State<_VanishTimerIndicator> {
  Timer? _timer;
  late DateTime _expirationTime;
  String _timeLeftStr = '';

  @override
  void initState() {
    super.initState();
    final durationSecs = _getVanishDuration(widget.message.messageType);
    _expirationTime =
        widget.message.createdAt.add(Duration(seconds: durationSecs));
    _updateTimeLeft();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateTimeLeft();
    });
  }

  int _getVanishDuration(String messageType) {
    final parts = messageType.split(':');
    if (parts.length > 1) {
      return int.tryParse(parts[1]) ?? 86400;
    }
    return 86400;
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    final diff = _expirationTime.difference(now);

    if (diff.isNegative) {
      _timer?.cancel();
      widget.onExpired();
      return;
    }

    if (!mounted) return;

    setState(() {
      if (diff.inDays > 0) {
        _timeLeftStr = '${diff.inDays}n';
      } else if (diff.inHours > 0) {
        _timeLeftStr = '${diff.inHours}g';
      } else if (diff.inMinutes > 0) {
        _timeLeftStr = '${diff.inMinutes}p';
      } else {
        _timeLeftStr = '${diff.inSeconds}s';
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.purple.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '👻',
            style: TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 3),
          Text(
            _timeLeftStr,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.purpleAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
