import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:realtime_client/src/types.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/date_extension.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/upstash_redis_service.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../shared/widgets/report_bottom_sheet.dart';
import '../../domain/conversation_member_model.dart';
import '../../domain/conversation_model.dart';
import '../../domain/message_model.dart';
import '../../domain/pinned_message_model.dart';
import '../../providers/chat_provider.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/voice_message_bubble.dart';
import '../widgets/voice_recorder_bar.dart';
import '../widgets/elastic_scroll_to_bottom_button.dart';
import '../widgets/chat_pinned_banner.dart';
import '../../presentation/widgets/message_popup_menu_content.dart';
import '../../presentation/widgets/message_context_menu_route.dart';
import '../../../social/data/ai_repository.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/localization/app_language.dart';

// ── Helper data class ─────────────────────────────────────────────────────────

class _MessageListItem {
  final bool isDivider;
  final bool isSystemMessage;
  final bool isUnreadDivider;
  final String? systemMessageText;
  final DateTime? dateTime;
  final MessageModel? message;
  final bool showInlineTime;
  final bool isLastInGroup;

  const _MessageListItem._({
    required this.isDivider,
    this.isSystemMessage = false,
    this.isUnreadDivider = false,
    this.systemMessageText,
    this.dateTime,
    this.message,
    this.showInlineTime = false,
    this.isLastInGroup = true,
  });

  factory _MessageListItem.divider(DateTime dt) =>
      _MessageListItem._(isDivider: true, dateTime: dt);

  factory _MessageListItem.unreadDivider() =>
      const _MessageListItem._(isDivider: false, isUnreadDivider: true);

  factory _MessageListItem.system(String text, DateTime dt) =>
      _MessageListItem._(
        isDivider: false,
        isSystemMessage: true,
        systemMessageText: text,
        dateTime: dt,
      );

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
({List<_MessageListItem> items, Map<String, int> indexMap}) _buildItemList(
    List<MessageModel> messages, {
    String? currentUserId,
    int unreadCount = 0,
    DateTime? lastReadAt,
}) {
  final items = <_MessageListItem>[];

  // Chỉ tìm ID tin nhắn chưa đọc đầu tiên KHI người dùng có unreadCount > 0
  String? firstUnreadMsgId;
  if (currentUserId != null && unreadCount > 0) {
    for (final m in messages.reversed) {
      if (m.senderId != currentUserId) {
        if (!m.isSeen && (lastReadAt == null || m.createdAt.isAfter(lastReadAt))) {
          firstUnreadMsgId = m.id;
          break;
        }
      }
    }
  }

  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];

    if (msg.isSystem) {
      items.add(_MessageListItem.system(msg.content ?? '', msg.createdAt));
      continue;
    }

    final olderMsg = i < messages.length - 1 ? messages[i + 1] : null;
    final newerMsg = i > 0 ? messages[i - 1] : null;

    final isLastInGroup = newerMsg == null ||
        newerMsg.isSystem ||
        newerMsg.senderId != msg.senderId ||
        newerMsg.createdAt.difference(msg.createdAt).inMinutes.abs() >= 5;

    items.add(_MessageListItem.message(
      msg,
      isLastInGroup: isLastInGroup,
      showInlineTime: isLastInGroup,
    ));

    // Hiển thị nhãn "Tin nhắn chưa đọc" PHÍA TRÊN tin nhắn chưa đọc đầu tiên
    // (Vì ListView reverse: true nên item được add tiếp theo sẽ ở vị trí cao hơn/phía trên trên màn hình)
    if (firstUnreadMsgId != null && msg.id == firstUnreadMsgId) {
      items.add(_MessageListItem.unreadDivider());
    }

    // Time divider nếu cách tin cũ hơn >= 10 phút, hoặc tin đầu tiên
    if (olderMsg == null ||
        olderMsg.isSystem ||
        msg.createdAt.difference(olderMsg.createdAt).inMinutes.abs() >= 10) {
      items.add(_MessageListItem.divider(msg.createdAt));
    }
  }

  // Build index map: messageId → index trong items
  final indexMap = <String, int>{};
  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    if (!item.isDivider && !item.isSystemMessage && !item.isUnreadDivider && item.message != null) {
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

  // Cache kết quả grouping để không tính lại trong mỗi build()
  List<MessageModel> _cachedMessages = [];
  List<_MessageListItem> _cachedItems = [];
  Map<String, int> _cachedIndexMap = {};

  // ID tin nhắn đang được highlight (sau khi scroll tới)
  String? _highlightedMessageId;

  // Trạng thái hiển thị nút cuộn xuống đáy
  bool _showScrollToBottomBtn = false;
  bool _hasScrolledToInitialUnread = false;

  // Realtime Typing Indicator State
  RealtimeChannel? _typingChannel;
  bool _isOtherUserTyping = false;
  String? _typingUserName;
  String? _typingAvatarUrl;
  Timer? _typingTimer;
  DateTime? _lastTypingSentTime;

  double _pullUpDistance = 0.0;
  bool _hasCrossedVanishThreshold = false;
  bool _isVanishTriggering = false;

  // Vanish gesture tracking (works on Web too)
  double? _vanishDragStartDy;
  bool _isAtBottom = true; // true when index-0 item is visible
  bool _isRecordingVoice = false;

  void _deleteExpiredMessage(String messageId) {
    Future.microtask(() async {
      try {
        await ref
            .read(realtimeMessagesProvider(widget.conversationId).notifier)
            .deleteMessage(messageId);
      } catch (err) {
        debugPrint('Failed to delete expired message: $err');
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Native overscroll path (iOS / Android)
    if (!kIsWeb) {
      if (_isVanishTriggering) {
        final pixels = notification.metrics.pixels;
        if (pixels >= 0.0) {
          setState(() {
            _isVanishTriggering = false;
            _pullUpDistance = 0.0;
            _hasCrossedVanishThreshold = false;
          });
        } else {
          setState(() {
            _pullUpDistance = -pixels;
          });
        }
        return false;
      }

      final pixels = notification.metrics.pixels;
      if (pixels < 0.0) {
        setState(() {
          _pullUpDistance = -pixels;
          if (_pullUpDistance > 300.0 && !_hasCrossedVanishThreshold) {
            _hasCrossedVanishThreshold = true;
            HapticFeedback.mediumImpact();
          } else if (_pullUpDistance <= 300.0 && _hasCrossedVanishThreshold) {
            _hasCrossedVanishThreshold = false;
          }
        });
      } else {
        if (_pullUpDistance != 0.0) {
          setState(() {
            _pullUpDistance = 0.0;
          });
        }
      }

      if (notification is UserScrollNotification &&
          notification.direction == ScrollDirection.idle) {
        if (_hasCrossedVanishThreshold) {
          _isVanishTriggering = true;
          _toggleVanishMode();
          setState(() {
            _hasCrossedVanishThreshold = false;
          });
        }
      }
    }
    return false;
  }

  Future<void> _toggleVanishMode() async {
    HapticFeedback.heavyImpact();
    await ref.read(vanishModeProvider.notifier).toggle(widget.conversationId);

    final isVanish = ref.read(vanishModeProvider)[widget.conversationId] ?? false;

    if (isVanish) {
      await ref.read(chatSelfDestructProvider.notifier).setSelfDestruct(widget.conversationId, 86400);
    } else {
      await ref.read(chatSelfDestructProvider.notifier).setSelfDestruct(widget.conversationId, 0);
    }

    final newSelfDestructSecs = ref.read(chatSelfDestructProvider)[widget.conversationId] ?? 0;
    final label = _formatDurationLabel(newSelfDestructSecs > 0 ? newSelfDestructSecs : 86400);

    // For "on" state: send system message with a special marker so the UI can show "Thay đổi"
    final text = isVanish
        ? "Tính năng tự hủy đã được bật. Tin nhắn mới sẽ tự động biến mất sau $label.|vanish_change"
        : "Tính năng tự hủy đã được tắt.";

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        widget.conversationId,
        text,
        messageType: 'system',
      );
    } catch (_) {}
  }

  void _showVanishBottomSheet(BuildContext context) {
    final selfDestructSecs =
        ref.read(chatSelfDestructProvider)[widget.conversationId] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E2F)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tin nhắn tự hủy',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Chọn thời gian tự động xóa tin nhắn sau khi gửi',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Tắt option
              _buildVanishOption(
                ctx: ctx,
                label: 'Tắt',
                isSelected: selfDestructSecs == 0,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(chatSelfDestructProvider.notifier)
                      .setSelfDestruct(widget.conversationId, 0);
                  await ref.read(vanishModeProvider.notifier)
                      .setVanish(widget.conversationId, false);
                },
              ),
              const Divider(height: 1),
              // 24 giờ option
              _buildVanishOption(
                ctx: ctx,
                label: '24 giờ',
                isSelected: selfDestructSecs == 86400,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(chatSelfDestructProvider.notifier)
                      .setSelfDestruct(widget.conversationId, 86400);
                  await ref.read(vanishModeProvider.notifier)
                      .setVanish(widget.conversationId, true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVanishOption({
    required BuildContext ctx,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: isSelected ? Colors.purpleAccent : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: Colors.purpleAccent)
          : null,
      onTap: onTap,
    );
  }


  String _formatDurationLabel(int seconds) {
    if (seconds == 86400) return '24 giờ';
    if (seconds == 604800) return '7 ngày';
    if (seconds == 2592000) return '30 ngày';
    if (seconds == 7776000) return '90 ngày';
    return '$seconds giây';
  }


  List<String> _decodeMediaUrls(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return [json];
  }

  int _getVanishDuration(String messageType) {
    final parts = messageType.split(':');
    if (parts.length > 1) {
      return int.tryParse(parts[1]) ?? 86400;
    }
    return 86400;
  }

  Widget _buildVanishPullIndicator() {
    if (_pullUpDistance < 10) return const SizedBox.shrink();

    final selfDestructState = ref.watch(chatSelfDestructProvider);
    final selfDestructSecs = selfDestructState[widget.conversationId] ?? 0;
    final vanishModeState = ref.watch(vanishModeProvider);
    final isVanishActive = (vanishModeState[widget.conversationId] ?? false) || (selfDestructSecs > 0);

    String text;
    if (isVanishActive) {
      text = _hasCrossedVanishThreshold
          ? "Thả tay để tắt tính năng tự hủy"
          : "Kéo lên để tắt tính năng tự hủy";
    } else {
      text = _hasCrossedVanishThreshold
          ? "Thả tay để bật tính năng tự hủy"
          : "Kéo lên để bật tính năng tự hủy";
    }

    final progress = (_pullUpDistance / 300.0).clamp(0.0, 1.0);

    return Container(
      height: 60,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _hasCrossedVanishThreshold ? Colors.purpleAccent : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: _hasCrossedVanishThreshold ? Colors.purpleAccent : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _messageController.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(realtimeMessagesProvider(widget.conversationId).notifier).markAsSeen();
      if (mounted) {
        ref.invalidate(conversationsProvider);
        ref.invalidate(unreadMessagesCountProvider);
        _subscribeTypingChannel();
      }
    });

    // Load thêm khi scroll lên đỉnh (tin cũ hơn)
    _itemPositionsListener.itemPositions.addListener(_onPositionChange);

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _subscribeTypingChannel() {
    try {
      final client = ref.read(supabaseServiceProvider).client;
      final currentUserId = ref.read(currentUserIdProvider);

      _typingChannel = client.channel('typing:${widget.conversationId}');
      _typingChannel!.onBroadcast(
        event: 'typing',
        callback: (payload) {
          final senderId = payload['userId'] as String?;
          final broadcastUserName = payload['userName'] as String?;
          final isTyping = payload['isTyping'] as bool? ?? true;

          if (senderId != null && senderId != currentUserId) {
            if (mounted) {
              if (isTyping) {
                // Resolved name logic
                final convs = ref.read(conversationsProvider).valueOrNull ?? [];
                final ConversationModel? conv = convs.cast<ConversationModel?>().firstWhere(
                  (c) => c?.id == widget.conversationId,
                  orElse: () => null,
                );

                String resolvedName;
                if (conv != null && !conv.isGroup && conv.otherUser?.displayName != null && conv.otherUser!.displayName!.isNotEmpty) {
                  resolvedName = conv.otherUser!.displayName!;
                } else {
                  final senderProfile = ref.read(profileProvider(senderId)).valueOrNull;
                  if (senderProfile?.displayName != null && senderProfile!.displayName!.isNotEmpty) {
                    resolvedName = senderProfile.displayName!;
                  } else if (senderProfile?.fullName != null && senderProfile!.fullName!.isNotEmpty) {
                    resolvedName = senderProfile.fullName!;
                  } else if (broadcastUserName != null && broadcastUserName.isNotEmpty && broadcastUserName != 'Thành viên') {
                    resolvedName = broadcastUserName;
                  } else {
                    resolvedName = 'Thành viên';
                  }
                }

                setState(() {
                  _isOtherUserTyping = true;
                  _typingUserName = resolvedName;
                  _typingAvatarUrl = null;
                });
                _typingTimer?.cancel();
                _typingTimer = Timer(const Duration(milliseconds: 3500), () {
                  if (mounted) {
                    setState(() {
                      _isOtherUserTyping = false;
                      _typingUserName = null;
                      _typingAvatarUrl = null;
                    });
                  }
                });
              } else {
                _typingTimer?.cancel();
                setState(() {
                  _isOtherUserTyping = false;
                  _typingUserName = null;
                  _typingAvatarUrl = null;
                });
              }
            }
          }
        },
      ).subscribe();
    } catch (e) {
      debugPrint('⚠️ [ChatScreen] Lỗi subscribe typing channel: $e');
    }
  }

  void _onTextChanged() {
    final text = _messageController.text.trim();
    final currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    if (text.isEmpty) {
      try {
        _typingChannel?.send(
          type: RealtimeListenTypes.broadcast,
          event: 'typing',
          payload: {'userId': currentUserId, 'isTyping': false},
        );
      } catch (_) {}
      return;
    }

    final now = DateTime.now();
    if (_lastTypingSentTime == null ||
        now.difference(_lastTypingSentTime!).inMilliseconds > 1500) {
      _lastTypingSentTime = now;

      final currentUser = ref.read(profileProvider(currentUserId)).valueOrNull;
      final supabaseUser = ref.read(supabaseServiceProvider).client.auth.currentUser;
      final userName = (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty)
          ? currentUser.displayName!
          : (currentUser?.fullName != null && currentUser!.fullName!.isNotEmpty)
              ? currentUser.fullName!
              : (supabaseUser?.userMetadata?['display_name'] ??
                  supabaseUser?.userMetadata?['full_name'] ??
                  supabaseUser?.email?.split('@').first ??
                  'Người dùng');
      final avatarUrl = currentUser?.avatarUrl;

      // 1. Set TTL 3s in Upstash Redis
      ref
          .read(upstashRedisServiceProvider)
          .setUserTyping(widget.conversationId, currentUserId);

      // 2. Broadcast realtime event
      try {
        _typingChannel?.send(
          type: RealtimeListenTypes.broadcast,
          event: 'typing',
          payload: {
            'userId': currentUserId,
            'userName': userName,
            'avatarUrl': avatarUrl,
            'isTyping': true,
          },
        );
      } catch (_) {}
    }
  }

  Widget _buildTypingBubble(ThemeData theme, String senderName) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2C2E).withValues(alpha: 0.9)
              : const Color(0xFFE9E9EB).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$senderName đang nhập',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            const _BouncingDots(),
          ],
        ),
      ),
    );
  }

  void _onPositionChange() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Cập nhật trạng thái hiển thị nút "cuộn xuống đáy"
    // Nếu index 0 (tin mới nhất) không hiển thị trong danh sách các item đang hiện diện trên màn hình,
    // hoặc có nhưng nó bị che khuất một phần (leadingEdge < 0)
    final hasLatest = positions.any((p) => p.index == 0);
    bool showBtn = !hasLatest;
    if (hasLatest) {
      final latestPosition = positions.firstWhere((p) => p.index == 0);
      if (latestPosition.itemLeadingEdge < 0) {
        showBtn = true;
      }
    }

    if (showBtn != _showScrollToBottomBtn) {
      setState(() {
        _showScrollToBottomBtn = showBtn;
        _isAtBottom = !showBtn; // isAtBottom = index-0 fully visible
      });
    } else {
      final newIsAtBottom = !showBtn;
      if (newIsAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = newIsAtBottom;
        });
      }
    }

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
    _messageController.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _typingChannel?.unsubscribe();
    _messageController.dispose();
    _focusNode.dispose();
    _itemPositionsListener.itemPositions.removeListener(_onPositionChange);
    super.dispose();
  }

  // ── Wallpaper Helpers ──────────────────────────────────────────────────────

  bool _isSystemWallpaper(String path) => path.startsWith('sys:');

  String? _getSystemAssetPath(String path) {
    if (!path.startsWith('sys:wp_')) return null;
    final match = RegExp(r'^sys:wp_(\d+)$').firstMatch(path);
    if (match != null) {
      final numStr = match.group(1);
      return 'assets/images/wallpapers/wallpaper$numStr.jpg';
    }
    return null;
  }

  DecorationImage? _getWallpaperDecorationImage(String path) {
    if (path.isEmpty) return null;

    ImageProvider imageProvider;
    if (_isSystemWallpaper(path)) {
      final assetPath = _getSystemAssetPath(path);
      if (assetPath != null) {
        imageProvider = AssetImage(assetPath);
      } else {
        return null;
      }
    } else if (path.startsWith('blob:')) {
      return null; // Skip invalid temporary blob URLs
    } else if (path.startsWith('http')) {
      imageProvider = CachedNetworkImageProvider(path);
    } else if (kIsWeb) {
      return null;
    } else {
      imageProvider = FileImage(io.File(path));
    }

    return DecorationImage(
      image: imageProvider,
      fit: BoxFit.cover,
      opacity: 0.85,
    );
  }

  BoxDecoration _getWallpaperDecoration(String path, ThemeData theme) {
    final image = _getWallpaperDecorationImage(path);
    return BoxDecoration(
      color: theme.scaffoldBackgroundColor,
      image: image,
    );
  }

  // ── Cập nhật cache grouping khi messages thay đổi ─────────────────────────

  bool _areReactionsEqual(Map<String, List<String>> r1, Map<String, List<String>> r2) {
    if (r1.length != r2.length) return false;
    for (final key in r1.keys) {
      if (!r2.containsKey(key)) return false;
      final l1 = r1[key]!;
      final l2 = r2[key]!;
      if (l1.length != l2.length) return false;
      for (int i = 0; i < l1.length; i++) {
        if (l1[i] != l2[i]) return false;
      }
    }
    return true;
  }

  void _updateCacheIfNeeded(List<MessageModel> messages) {
    // Rebuild cache nếu số lượng thay đổi, id đầu/cuối thay đổi,
    // HOẶC bất kỳ message nào có messageType, content, hoặc reactions khác
    bool needsUpdate = false;

    if (messages.length != _cachedMessages.length) {
      needsUpdate = true;
    } else if (messages.isNotEmpty) {
      if (messages.first.id != _cachedMessages.first.id ||
          messages.last.id != _cachedMessages.last.id) {
        needsUpdate = true;
      } else {
        // Kiểm tra xem có message nào bị thay đổi trạng thái hoặc reactions không
        for (int i = 0; i < messages.length; i++) {
          final m1 = messages[i];
          final m2 = _cachedMessages[i];
          if (m1.messageType != m2.messageType ||
              m1.content != m2.content ||
              !_areReactionsEqual(m1.reactions, m2.reactions)) {
            needsUpdate = true;
            break;
          }
        }
      }
    }

    if (!needsUpdate) return;

    _cachedMessages = messages;
    final currentUserId = ref.read(currentUserIdProvider);
    
    // Lấy trạng thái unread & lastReadAt của người dùng từ conversation
    final convs = ref.read(conversationsProvider).valueOrNull ?? [];
    ConversationModel? conv;
    try {
      conv = convs.firstWhere((c) => c.id == widget.conversationId);
    } catch (_) {}

    final unreadCount = conv?.unreadCount ?? 0;
    final lastReadAt = conv?.myMemberState?.lastReadAt;

    final result = _buildItemList(
      messages,
      currentUserId: currentUserId,
      unreadCount: unreadCount,
      lastReadAt: lastReadAt,
    );
    _cachedItems = result.items;
    _cachedIndexMap = result.indexMap;

    // Tự động cuộn đến tin nhắn chưa đọc đầu tiên ở lần đầu nạp danh sách
    if (!_hasScrolledToInitialUnread && _cachedItems.isNotEmpty) {
      _hasScrolledToInitialUnread = true;
      int? unreadTargetIndex;
      for (int i = 0; i < _cachedItems.length; i++) {
        if (_cachedItems[i].isUnreadDivider) {
          unreadTargetIndex = i;
          break;
        }
      }

      if (unreadTargetIndex != null && unreadTargetIndex > 0) {
        final targetIndex = unreadTargetIndex;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_itemScrollController.isAttached) {
            _itemScrollController.jumpTo(
              index: targetIndex,
              alignment: 0.3,
            );
          }
        });
      }
    }
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

    final vanishModeState = ref.read(vanishModeProvider);
    final isVanishMode = vanishModeState[widget.conversationId] ?? false;
    final selfDestructState = ref.read(chatSelfDestructProvider);
    final selfDestructSecs = selfDestructState[widget.conversationId] ?? 0;
    final vanishDuration = selfDestructSecs > 0 ? selfDestructSecs : 86400;

    final msgType = isVanishMode
        ? (image != null ? 'vanish_image:$vanishDuration' : 'vanish_text:$vanishDuration')
        : (image != null ? 'image' : 'text');

    setState(() {
      _sending = true;
      _pendingImage = null;
      _pendingImagePreviewBytes = null;
      _replyingToMessage = null;
    });
    _messageController.clear();

    try {
      if (image != null) {
        final sentMsg = await ref.read(chatRepositoryProvider).sendImageMessage(
              widget.conversationId,
              image,
              caption: text.isNotEmpty ? text : null,
              replyToMessageId: replyId,
              messageType: msgType,
            );
        // Thêm ngay vào state — không cần chờ realtime
        ref
            .read(realtimeMessagesProvider(widget.conversationId).notifier)
            .addOptimisticMessage(sentMsg);
      } else if (text.isNotEmpty) {
        await ref
            .read(chatRepositoryProvider)
            .sendMessage(widget.conversationId, text,
                replyToMessageId: replyId,
                messageType: msgType);
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
                mediaUrls: [image.path],
                messageType: msgType,
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
                messageType: msgType,
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
    final wallpaperState = ref.watch(chatWallpaperProvider);
    final wallpaperPath = wallpaperState[widget.conversationId] ?? '';

    final selfDestructState = ref.watch(chatSelfDestructProvider);
    final selfDestructSecs = selfDestructState[widget.conversationId] ?? 0;

    final vanishModeState = ref.watch(vanishModeProvider);
    final isVanishMode = (vanishModeState[widget.conversationId] ?? false) || (selfDestructSecs > 0);

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[widget.conversationId] ?? 'blue';
    final chatThemeColor = getChatThemePrimaryColor(themeName);

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
        ref.read(realtimeMessagesProvider(widget.conversationId).notifier).markAsSeen().then((_) {
          if (mounted) {
            ref.invalidate(conversationsProvider);
            ref.invalidate(unreadMessagesCountProvider);
          }
        });
        final positions = _itemPositionsListener.itemPositions.value;
        final isNearBottom =
            positions.isEmpty || positions.any((p) => p.index == 0);
        if (isNearBottom) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        }
      }
    });

    // Lấy thông tin cuộc trò chuyện
    final convAsync = ref.watch(conversationsProvider);
    final conversation = convAsync.whenData((convs) {
      try {
        return convs.firstWhere((c) => c.id == widget.conversationId);
      } catch (_) {
        return null;
      }
    }).valueOrNull;

    final isGroup = conversation?.isGroup ?? false;
    final otherUser = conversation?.otherUser;

    final titleName = isGroup
        ? (conversation?.name?.isNotEmpty == true ? conversation!.name! : 'Nhóm trò chuyện')
        : (otherUser?.displayName ?? 'Chat');

    final displayAvatarUrl = isGroup
        ? conversation?.avatarUrl
        : otherUser?.avatarUrl;

    final otherUserName = titleName;

    // Dùng chat_blocks (bảng riêng, độc lập với blocks của profile/feed)
    final isBlocked = ref.watch(isChatBlockedProvider(otherUser?.id ?? ''));
    final isBlockedBy = ref.watch(isChatBlockedByProvider(otherUser?.id ?? '')).valueOrNull ?? false;

    final hasWallpaper = wallpaperPath.isNotEmpty;

    Widget buildHeaderButton({
      required Widget icon,
      required VoidCallback onPressed,
      String? tooltip,
    }) {
      return Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: IconButton(
          icon: icon,
          onPressed: onPressed,
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          splashRadius: 18,
        ),
      );
    }

    Widget scaffold = Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: hasWallpaper
            ? Colors.transparent
            : theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 12, right: 8),
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: IconButton(
                icon: const Icon(
                  CupertinoIcons.chevron_back,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                splashRadius: 18,
              ),
            ),
            Flexible(
              child: GestureDetector(
                onTap: () {
                  if (isGroup) {
                    context.push('/chat/${widget.conversationId}/settings');
                  } else if (otherUser != null) {
                    context.push('/profile/${otherUser.id}');
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppAvatar(
                      imageUrl: displayAvatarUrl,
                      name: titleName,
                      radius: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        titleName,
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
          buildHeaderButton(
            icon: const Icon(CupertinoIcons.videocam_circle,
                color: Colors.white, size: 22),
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
          buildHeaderButton(
            icon: const Icon(CupertinoIcons.phone,
                color: Colors.white, size: 18),
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
          buildHeaderButton(
            icon: const Icon(CupertinoIcons.ellipsis,
                color: Colors.white, size: 18),
            onPressed: () => context.push('/chat/${widget.conversationId}/settings'),
            tooltip: 'Thêm',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: hasWallpaper ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.25),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (pinnedMessages.isNotEmpty)
              ChatPinnedBanner(
                conversationId: widget.conversationId,
                pinnedList: pinnedMessages,
                currentUserId: currentUserId,
                otherUserName: otherUserName,
                hasWallpaper: hasWallpaper,
                onJumpToMessage: (pin) => _jumpToPinnedMessage(pin),
                onUnpinMessage: (messageId) async {
                  try {
                    await ref
                        .read(chatRepositoryProvider)
                        .unpinMessage(widget.conversationId, messageId);
                    ref.invalidate(pinnedMessagesProvider(widget.conversationId));
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bỏ ghim thất bại: $e')),
                      );
                    }
                  }
                },
              ),
            Expanded(
              child: Stack(
                children: [
                  if (isVanishMode) const _VanishBackground(),
                  messagesAsync.when(
                    data: (messagesState) {
                      final failedModels = messagesState.failedMessages.map((f) {
                        return MessageModel(
                          id: f.localId,
                          conversationId: f.conversationId,
                          senderId: f.senderId,
                          content: f.content,
                          mediaUrls: _decodeMediaUrls(f.mediaUrlsJson),
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

                      final now = DateTime.now();
                      final displayedMessages = <MessageModel>[];
                      for (final m in allMessages) {
                        if (m.isVanish) {
                          final duration = _getVanishDuration(m.messageType);
                          final expirationTime = m.createdAt.add(Duration(seconds: duration));
                          if (now.isAfter(expirationTime)) {
                            _deleteExpiredMessage(m.id);
                            continue;
                          }
                        }
                        displayedMessages.add(m);
                      }

                      _updateCacheIfNeeded(displayedMessages);

                      Widget listWidget = NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: _buildMessageList(
                          messagesState,
                          displayedMessages,
                          currentUserId,
                          otherUserName,
                          pinnedIds,
                          isGroup,
                        ),
                      );

                      // On Web, BouncingScrollPhysics overscroll doesn't fire,
                      // so we use a Listener (receives pointer events unconditionally,
                      // never "stolen" by child scroll widgets) to simulate pull-up vanish.
                      if (kIsWeb) {
                        listWidget = Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (event) {
                            if (_isAtBottom) {
                              _vanishDragStartDy = event.position.dy;
                            }
                          },
                          onPointerMove: (event) {
                            if (_vanishDragStartDy == null) return;
                            final dy = _vanishDragStartDy! - event.position.dy; // positive = dragging up
                            if (dy > 0) {
                              setState(() {
                                _pullUpDistance = dy;
                                if (dy > 300.0 && !_hasCrossedVanishThreshold) {
                                  _hasCrossedVanishThreshold = true;
                                  HapticFeedback.mediumImpact();
                                } else if (dy <= 300.0 && _hasCrossedVanishThreshold) {
                                  _hasCrossedVanishThreshold = false;
                                }
                              });
                            } else if (_pullUpDistance > 0) {
                              // dragging back down — reset indicator
                              setState(() {
                                _pullUpDistance = 0.0;
                                _hasCrossedVanishThreshold = false;
                              });
                            }
                          },
                          onPointerUp: (event) {
                            if (_hasCrossedVanishThreshold) {
                              _toggleVanishMode();
                            }
                            setState(() {
                              _pullUpDistance = 0.0;
                              _hasCrossedVanishThreshold = false;
                              _vanishDragStartDy = null;
                            });
                          },
                          onPointerCancel: (event) {
                            setState(() {
                              _pullUpDistance = 0.0;
                              _hasCrossedVanishThreshold = false;
                              _vanishDragStartDy = null;
                            });
                          },
                          child: listWidget,
                        );
                      }

                      return listWidget;
                    },
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                    error: (e, _) => Center(child: Text(e.toString())),
                  ),
                  if (_pullUpDistance > 5)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: _buildVanishPullIndicator(),
                    ),
                  // Nút cuộn xuống đáy cao cấp (Scroll to Bottom button)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: AnimatedScale(
                      scale: _showScrollToBottomBtn ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: _showScrollToBottomBtn ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: ElasticScrollToBottomButton(
                          onTap: () => _scrollToBottom(),
                          themeColor: chatThemeColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildInput(theme, hasWallpaper, isBlocked, isBlockedBy),
          ],
        ),
      ),
    );

    if (hasWallpaper) {
      scaffold = Container(
        decoration: _getWallpaperDecoration(wallpaperPath, theme),
        child: scaffold,
      );
    }

    return scaffold;
  }

  // ── Message List ──────────────────────────────────────────────────────────────

  Widget _buildMessageList(
    ChatMessagesState messagesState,
    List<MessageModel> messages,
    String currentUserId,
    String otherUserName,
    Set<String> pinnedIds,
    bool isGroup,
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

    final showTyping = _isOtherUserTyping && _typingUserName != null;
    final extraCount = (isLoadingMore ? 1 : 0) + (showTyping ? 1 : 0);

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      reverse: true, // index 0 = đáy màn hình = tin mới nhất
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _cachedItems.length + extraCount,
      itemBuilder: (context, index) {
        if (showTyping && index == 0) {
          return _buildTypingBubble(Theme.of(context), _typingUserName!);
        }

        final itemIndex = showTyping ? index - 1 : index;

        // Spinner load thêm (hiển thị trên cùng)
        if (itemIndex == _cachedItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final item = _cachedItems[itemIndex];

        if (item.isUnreadDivider) {
          return const _UnreadDivider();
        }

        if (item.isDivider) {
          return _TimeDivider(dateTime: item.dateTime!);
        }

        if (item.isSystemMessage) {
          final rawText = item.systemMessageText!;
          final hasChangeTap = rawText.endsWith('|vanish_change');
          final displayText = hasChangeTap
              ? rawText.substring(0, rawText.length - '|vanish_change'.length)
              : rawText;
          return _SystemMessageDivider(
            text: displayText,
            onChangeTap: hasChangeTap ? () => _showVanishBottomSheet(context) : null,
          );
        }

        final msg = item.message!;
        final isHighlighted = _highlightedMessageId == msg.id;

        bool showSenderInfo = true;
        if (isGroup && !isMine) {
          final olderItemIndex = itemIndex + 1;
          if (olderItemIndex < _cachedItems.length) {
            final olderItem = _cachedItems[olderItemIndex];
            if (!olderItem.isDivider && !olderItem.isSystemMessage && olderItem.message != null) {
              if (olderItem.message!.senderId == msg.senderId) {
                showSenderInfo = false;
              }
            }
          }
        }

        return _MessageBubble(
          key: ValueKey(msg.id), // ValueKey đơn giản, không cần GlobalKey
          message: msg,
          isMine: msg.senderId == currentUserId,
          isGroup: isGroup,
          showSenderInfo: showSenderInfo,
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



  // ── Image Preview ─────────────────────────────────────────────────────────────

  Widget _buildImagePreview(ThemeData theme, bool hasWallpaper) {
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
        color: hasWallpaper
            ? theme.scaffoldBackgroundColor.withValues(alpha: 0.7)
            : theme.scaffoldBackgroundColor,
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

  Widget _buildReplyPreview(ThemeData theme, bool hasWallpaper) {
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
    final replySenderProfile = ref.watch(profileProvider(msg.senderId)).valueOrNull;
    final senderName = msg.senderId == currentUserId
        ? 'Bạn'
        : (replySenderProfile?.displayName ?? replySenderProfile?.fullName ?? otherUserName);
    final replyContent = msg.isText
        ? msg.content
        : (msg.isVoice ? 'Tin nhắn thoại' : (msg.isImage ? 'Hình ảnh' : 'Cuộc gọi'));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: hasWallpaper
            ? theme.scaffoldBackgroundColor.withValues(alpha: 0.7)
            : (isDark ? theme.colorScheme.surface : theme.scaffoldBackgroundColor),
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
          if (msg.isImage && msg.firstMediaUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: msg.firstMediaUrl!,
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

  Widget _buildInput(ThemeData theme, bool hasWallpaper, bool isBlocked, bool isBlockedBy) {
    final isDark = theme.brightness == Brightness.dark;

    // ━━ Banner: Bạn đang chặn người kia ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    if (isBlocked || isBlockedBy) {
      final message = isBlocked
          ? 'Bạn đang chặn người dùng này'
          : 'Bạn đã bị chặn bởi người dùng này';
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: hasWallpaper
              ? theme.scaffoldBackgroundColor.withValues(alpha: 0.85)
              : theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isBlocked ? CupertinoIcons.slash_circle_fill : CupertinoIcons.lock_fill,
              color: Colors.red.withValues(alpha: 0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final hasPendingImage = _pendingImage != null;

    final selfDestructState = ref.watch(chatSelfDestructProvider);
    final selfDestructSecs = selfDestructState[widget.conversationId] ?? 0;
    final vanishModeState = ref.watch(vanishModeProvider);
    final isVanishMode = (vanishModeState[widget.conversationId] ?? false) || (selfDestructSecs > 0);

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[widget.conversationId] ?? 'blue';
    final chatThemeColor = getChatThemePrimaryColor(themeName);

    if (_isRecordingVoice) {
      return VoiceRecorderBar(
        themeColor: isVanishMode ? Colors.purpleAccent : chatThemeColor,
        onCancel: () {
          setState(() {
            _isRecordingVoice = false;
          });
        },
        onSend: (bytes, durationSeconds) async {
          setState(() {
            _isRecordingVoice = false;
          });
          final replyId = _replyingToMessage?.id;
          final selfDestructState = ref.read(chatSelfDestructProvider);
          final selfDestructSecs = selfDestructState[widget.conversationId] ?? 0;
          final vanishDuration = selfDestructSecs > 0 ? selfDestructSecs : 86400;
          final msgType = isVanishMode ? 'vanish_voice:$vanishDuration' : 'voice';

          try {
            await ref.read(chatRepositoryProvider).sendVoiceMessage(
                  widget.conversationId,
                  bytes,
                  durationSeconds: durationSeconds,
                  replyToMessageId: replyId,
                  messageType: msgType,
                );
            if (mounted) {
              setState(() {
                _replyingToMessage = null;
              });
              ref.invalidate(realtimeMessagesProvider(widget.conversationId));
              ref.invalidate(conversationsProvider);
            }
          } catch (e) {
            debugPrint('Error sending voice message: $e');
          }
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyingToMessage != null) _buildReplyPreview(theme, hasWallpaper),
        if (hasPendingImage) _buildImagePreview(theme, hasWallpaper),
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: hasWallpaper
                ? theme.scaffoldBackgroundColor.withValues(alpha: 0.7)
                : theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      axis: Axis.horizontal,
                      sizeFactor: animation,
                      child: child,
                    ),
                  ),
                  child: (!_focusNode.hasFocus && _messageController.text.isEmpty && !hasPendingImage)
                      ? Row(
                          key: const ValueKey('icons'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _sending ? null : _pickImage,
                              icon: Icon(
                                CupertinoIcons.photo,
                                color: hasPendingImage
                                    ? chatThemeColor
                                    : (isDark ? Colors.white60 : Colors.black45),
                                size: 22,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: _sending ? null : () => setState(() => _isRecordingVoice = true),
                              icon: Icon(
                                CupertinoIcons.mic_fill,
                                color: isDark ? Colors.white60 : Colors.black45,
                                size: 22,
                              ),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                          ],
                        )
                      : (_focusNode.hasFocus && _messageController.text.isEmpty && !hasPendingImage)
                          ? Row(
                              key: const ValueKey('chevron'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTapDown: (_) {
                                    Future.microtask(() {
                                      FocusScope.of(context).unfocus();
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      CupertinoIcons.chevron_right,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    cursorColor: isVanishMode ? Colors.purpleAccent : chatThemeColor,
                    decoration: InputDecoration(
                      hintText: hasPendingImage
                          ? 'Thêm chú thích...'
                          : 'Nhắn tin...',
                      hintStyle: TextStyle(
                          color: theme.hintColor, fontSize: 15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: isVanishMode
                            ? const BorderSide(color: Colors.purpleAccent, width: 1.5)
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: isVanishMode
                            ? const BorderSide(color: Colors.purpleAccent, width: 1.5)
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: isVanishMode
                            ? const BorderSide(color: Colors.purpleAccent, width: 2.0)
                            : BorderSide(color: chatThemeColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surface
                          : theme.scaffoldBackgroundColor,
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
                      ? (isVanishMode ? Colors.purpleAccent : chatThemeColor)
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

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: primaryColor.withValues(alpha: 0.35),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'Tin nhắn chưa đọc',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: primaryColor.withValues(alpha: 0.35),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemMessageDivider extends StatelessWidget {
  final String text;
  final VoidCallback? onChangeTap;

  const _SystemMessageDivider({required this.text, this.onChangeTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                  height: 1.3,
                ),
              ),
              if (onChangeTap != null) ...
                [
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onChangeTap,
                    child: const Text(
                      'Thay đổi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purpleAccent,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.purpleAccent,
                      ),
                    ),
                  ),
                ],
            ],
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

  const _MessageBubble({
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
  });

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  bool _tapped = false;
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

    // Nếu đã dịch rồi thì chỉ ẩn/hiện, không gọi API lại
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

      final targetLanguage =
          currentLanguage == AppLanguage.en ? 'en' : 'vi';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportBottomSheet(
        contentId: message.id,
        contentType: 'message',
        reporterId: widget.currentUserId,
      ),
    );
  }

  void _showCustomContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    final renderBox = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isMine = widget.isMine;
    final message = widget.message;

    final themeState = ref.read(chatThemeColorProvider);
    final themeName = themeState[message.conversationId] ?? 'blue';
    final myBubbleColor = getChatThemeColor(themeName, isDark: isDark);
    final theirBubbleColor = isDark
        ? AppColors.darkChatBubbleReceiver
        : AppColors.chatBubbleReceiver;
    final myTextColor = (themeName == 'blue')
        ? (isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender)
        : Colors.white;
    final theirTextColor = isDark
        ? AppColors.darkChatTextReceiver
        : AppColors.chatTextReceiver;

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
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                        ? const Radius.circular(12)
                        : Radius.zero,
                    bottomRight: message.isImage
                        ? const Radius.circular(12)
                        : Radius.zero,
                  ),
                ),
                margin: EdgeInsets.only(bottom: message.isImage ? 4 : 0),
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
                                if (message.replyToMessage!.senderId == widget.currentUserId) return 'Bạn';
                                final replyProfile = ref.watch(profileProvider(message.replyToMessage!.senderId)).valueOrNull;
                                return replyProfile?.displayName ?? replyProfile?.fullName ?? (widget.isGroup ? 'Thành viên' : widget.otherUserName);
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
                                  : (message.replyToMessage!.isImage
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
                              imageUrl: message.replyToMessage!.firstMediaUrl!,
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.withValues(alpha: 0.2),
                                width: 32,
                                height: 32,
                              ),
                              errorWidget: (_, __, ___) => const Icon(
                                  CupertinoIcons.photo,
                                  size: 16),
                            ),
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
            else if (message.isCall)
              _CallLogBubble(message: message, isMine: isMine)
            else
              Padding(
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
    );

    Navigator.push(
      context,
      MessageContextMenuRoute(
        messagePosition: position,
        messageSize: size,
        messageWidget: overlayBubbleWidget,
        isMine: isMine,
        menuContentWidget: MessagePopupMenuContent(
          isMine: isMine,
          isPinned: widget.isPinned,
          isText: message.isText,
          hasMyReaction: message.reactions.values.any((users) => users.contains(widget.currentUserId)),
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
          onPin: () {
            Navigator.pop(context);
            widget.onPin?.call();
          },
          onUnpin: () {
            Navigator.pop(context);
            widget.onUnpin?.call();
          },
          onCopy: () {
            Navigator.pop(context);
            Clipboard.setData(ClipboardData(text: message.content ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Đã sao chép tin nhắn vào bộ nhớ tạm'),
              duration: Duration(seconds: 1),
            ));
          },
          onForward: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Chức năng chuyển tiếp tin nhắn đang được phát triển'),
              duration: Duration(seconds: 1),
            ));
          },
          onRecall: isMine
              ? () {
                  Navigator.pop(context);
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('Thu hồi tin nhắn'),
                      content: const Text('Tin nhắn này sẽ bị thu hồi ở cả 2 phía. Bạn có chắc chắn muốn thu hồi không?'),
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
                            // UI cập nhật ngay lập tức (optimistic), DB sync ngầm
                            ref
                                .read(realtimeMessagesProvider(message.conversationId).notifier)
                                .recallMessage(message.id);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
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
            showCupertinoDialog(
              context: context,
              builder: (ctx) => CupertinoAlertDialog(
                title: const Text('Xóa tin nhắn'),
                content: const Text('Tin nhắn này chỉ bị xóa ở phía bạn, đối phương vẫn sẽ nhìn thấy. Bạn có chắc chắn muốn xóa?'),
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
                      await ref
                          .read(realtimeMessagesProvider(message.conversationId).notifier)
                          .deleteMessageLocally(message.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Đã xóa tin nhắn phía bạn'),
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
              content: Text('Gửi lúc: ${message.createdAt.toLocal().toString()}'),
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
    return local.localTimeHHmm;
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

    final themeState = ref.watch(chatThemeColorProvider);
    final themeName = themeState[message.conversationId] ?? 'blue';
    final myBubbleColor = getChatThemeColor(themeName, isDark: isDark);
    final theirBubbleColor = isDark
        ? AppColors.darkChatBubbleReceiver
        : AppColors.chatBubbleReceiver;
    final myTextColor = (themeName == 'blue')
        ? (isDark ? AppColors.darkChatTextSender : AppColors.chatTextSender)
        : Colors.white;
    final theirTextColor = isDark
        ? AppColors.darkChatTextReceiver
        : AppColors.chatTextReceiver;
    final replyThemeColor = getChatThemePrimaryColor(themeName);

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
    final senderMember = groupMembers?.cast<ConversationMemberModel?>().firstWhere(
      (m) => m?.userId == message.senderId,
      orElse: () => null,
    );

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

    final showTime = _tapped || widget.showInlineTime;

    final hasCaption = message.isImage &&
        message.content != null &&
        message.content != 'Đã gửi một ảnh' &&
        message.content!.trim().isNotEmpty;

    Widget bubbleContent = SwipeToReply(
      key: _bubbleKey,
      enabled: !message.isFailed && !message.isRecalled,
      replyThemeColor: replyThemeColor,
      onReply: () => widget.onSwipeToReply?.call(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: message.isRecalled
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1))
              : (isHighlighted
                  ? theme.colorScheme.primary.withValues(alpha: 0.25)
                  : (message.isImage && !hasCaption
                      ? Colors.transparent
                      : (isMine ? myBubbleColor : theirBubbleColor))),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine && widget.isGroup && widget.showSenderInfo)
                Padding(
                  padding: const EdgeInsets.only(left: 14, right: 14, top: 8, bottom: 2),
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
              // Quote box (reply preview bên trong bubble)
              if (message.replyToMessage != null && !message.isRecalled)
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
                                    if (message.replyToMessage!.senderId == widget.currentUserId) return 'Bạn';
                                    final replyProfile = ref.watch(profileProvider(message.replyToMessage!.senderId)).valueOrNull;
                                    return replyProfile?.displayName ?? replyProfile?.fullName ?? (widget.isGroup ? 'Thành viên' : widget.otherUserName);
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
                                      : (message.replyToMessage!.isImage
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
                                  imageUrl: message.replyToMessage!.firstMediaUrl!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    width: 32,
                                    height: 32,
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
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
              if (message.isRecalled)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.content ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: isMine ? myTextColor : theirTextColor,
                          height: 1.35,
                        ),
                      ),
                      // Bản dịch AI (bên trong bubble, giống STT của voice)
                      if (_isTranslating || _showTranslation) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.16)
                                : getChatThemePrimaryColor(themeName).withValues(alpha: 0.1),
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
                                              : getChatThemePrimaryColor(themeName))
                                          .withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _translatedText ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isMine ? myTextColor : theirTextColor,
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
            onDoubleTap: message.isFailed || message.isRecalled ? null : widget.onSwipeToReply,
            onSecondaryTapDown: message.isFailed || message.isRecalled
                ? (message.isFailed ? (d) => _showFailedMessageMenu(context) : null)
                : (d) => _showCustomContextMenu(context),
            onLongPressStart: message.isFailed || message.isRecalled
                ? (message.isFailed ? (d) => _showFailedMessageMenu(context) : null)
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

// ── Reaction Bar ─────────────────────────────────────────────────────────────────

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

    final activeReactions = reactions.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();

    if (activeReactions.isEmpty) return const SizedBox.shrink();

    // Sắp xếp các emoji theo số lượng thả giảm dần
    activeReactions.sort((a, b) => b.value.length.compareTo(a.value.length));

    // Lấy tối đa 2 emoji có lượt react nhiều nhất
    final topReactions = activeReactions.take(2).toList();
    final totalCount = activeReactions.fold<int>(0, (sum, entry) => sum + entry.value.length);
    final iReacted = activeReactions.any((entry) => entry.value.contains(currentUserId));

    final pillBgColor = iReacted
        ? (isDark ? const Color(0xFF1B3D6D) : const Color(0xFFD0ECFC))
        : (isDark ? const Color(0xFF2E2E3E) : const Color(0xFFEBEBEB));

    final pillBorderColor = iReacted
        ? (isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.3))
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08));

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
                fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
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
    return GestureDetector(
      onTap: () => FullScreenImageViewer.open(context, url),
      child: Hero(
        tag: url,
        child: ClipRRect(
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

    // FA233B for received; lighter coral for sent so it reads clearly on any
    // coloured theme background while still conveying missed/cancelled status.
    final missedColor = isMine
        ? const Color(0xFFFFB2B2)   // coral đỏ nhạt – dễ đọc trên mọi nền màu
        : const Color(0xFFFF2D55);  // đỏ Apple đặc trưng
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
    final progress =
        (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);
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
                                color: replyThemeColor
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
                            : replyThemeColor,
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

// ── Reactions Bottom Sheet ───────────────────────────────────────────────────

class _ReactionsBottomSheet extends ConsumerStatefulWidget {
  final MessageModel message;
  final String currentUserId;

  const _ReactionsBottomSheet({
    required this.message,
    required this.currentUserId,
  });

  @override
  ConsumerState<_ReactionsBottomSheet> createState() => _ReactionsBottomSheetState();
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
    final totalCount = activeReactions.fold<int>(0, (sum, entry) => sum + entry.value.length);

    final List<({String id, String label, int count})> tabs = [
      (id: 'all', label: 'Tất cả', count: totalCount),
      ...activeReactions.map((entry) => (id: entry.key, label: entry.key, count: entry.value.length)),
    ];

    final List<({String userId, String emoji})> items = [];
    if (_selectedTab == 'all') {
      for (final entry in activeReactions) {
        for (final userId in entry.value) {
          items.add((userId: userId, emoji: entry.key));
        }
      }
    } else {
      final entry = activeReactions.firstWhere((e) => e.key == _selectedTab, orElse: () => activeReactions.first);
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white10 : Colors.black12),
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
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${tab.count}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? theme.colorScheme.primary : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const Divider(height: 24),
      ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ReactionUserRow(
              userId: item.userId,
              emoji: item.emoji,
              currentUserId: widget.currentUserId,
            ),
          )),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.90,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView.builder(
            controller: scrollController,
            itemCount: listChildren.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return listChildren[index];
            },
          ),
        );
      },
    );
  }
}

class _ReactionUserRow extends ConsumerWidget {
  final String userId;
  final String emoji;
  final String currentUserId;

  const _ReactionUserRow({
    required this.userId,
    required this.emoji,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider(userId));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          profileAsync.when(
            data: (p) => AppAvatar(
              imageUrl: p.avatarUrl,
              name: p.displayName,
              radius: 18,
            ),
            loading: () => const CircleAvatar(
              radius: 18,
              child: CupertinoActivityIndicator(radius: 8),
            ),
            error: (_, __) => const CircleAvatar(
              radius: 18,
              child: Icon(CupertinoIcons.person),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: profileAsync.when(
              data: (p) {
                final isMe = userId == currentUserId;
                return Text(
                  isMe ? 'Bạn' : p.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
              loading: () => const Text('Đang tải...'),
              error: (_, __) => const Text('Người dùng'),
            ),
          ),
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 18,
              fontFamilyFallback: ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji'],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Vanish Timer Indicator Widget ─────────────────────────────────────────────

class _VanishTimerIndicator extends StatefulWidget {
  final MessageModel message;
  final VoidCallback onExpired;

  const _VanishTimerIndicator({
    super.key,
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
    _expirationTime = widget.message.createdAt.add(Duration(seconds: durationSecs));
    _updateTimeLeft();

    // Update every 10 seconds for general efficiency, or every second if less than a minute remains
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
        border: Border.all(color: Colors.purple.withValues(alpha: 0.25), width: 0.5),
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

// ── Vanish Floating Ghosts Background Widget ──────────────────────────────────

class _VanishBackground extends StatefulWidget {
  const _VanishBackground();

  @override
  State<_VanishBackground> createState() => _VanishBackgroundState();
}

class _VanishBackgroundState extends State<_VanishBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        return Stack(
          children: List.generate(6, (index) {
            final t = (_controller.value + (index / 6.0)) % 1.0;
            final y = size.height * (1.0 - t);
            final x = (size.width * 0.1) + ((index * 67) % (size.width * 0.8));
            final opacity = (1.0 - (t - 0.5).abs() * 2.0).clamp(0.0, 0.18); // Max opacity 18% for better visibility

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: opacity,
                child: const Text(
                  '👻',
                  style: TextStyle(fontSize: 36),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Bouncing Dots Typing Animation ────────────────────────────────────────────

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final dVal = (val - delay) % 1.0;
            final offsetY =
                (dVal < 0.5) ? -4.0 * (1 - (dVal * 2 - 1).abs()) : 0.0;

            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}