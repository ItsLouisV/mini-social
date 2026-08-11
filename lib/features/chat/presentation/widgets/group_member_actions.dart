
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/conversation_member_model.dart';
import 'message_context_menu_route.dart';

/// Menu action dùng chung cho thành viên nhóm.
///
/// Dùng được ở:
/// - ConversationSettingsScreen
/// - GroupMembersScreen
///
/// Action nào có callback != null thì mới hiển thị.
class GroupMemberActions {
  GroupMemberActions._();

  static Future<void> show({
    required BuildContext context,
    required ConversationMemberModel member,
    required GlobalKey itemKey,

    required bool isCurrentUser,
    required bool currentUserIsOwner,
    required bool currentUserIsAdmin,

    required VoidCallback onViewProfile,

    VoidCallback? onMessage,
    VoidCallback? onMakeAdmin,
    VoidCallback? onRemoveAdmin,
    VoidCallback? onTransferOwnership,
    VoidCallback? onMuteMember,
    VoidCallback? onBanMember,
    VoidCallback? onRemoveMember,
  }) async {
    HapticFeedback.mediumImpact();

    final renderBox = itemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBackground = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final memberName = member.profile?.displayName ?? 'Thành viên';
    final username = member.profile?.username ?? '';

    final overlayMemberWidget = Container(
      width: size.width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: member.profile?.avatarUrl,
            name: memberName,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '$memberName (Tôi)' : memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (username.isNotEmpty)
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
          ),
          if (member.isOwner)
            const FaIcon(
              FontAwesomeIcons.crown,
              size: 14,
              color: Colors.amber,
            )
          else if (member.isCoAdmin)
            const Icon(
              CupertinoIcons.star_fill,
              size: 16,
              color: Colors.purple,
            ),
        ],
      ),
    );

    final actionCount = 1 +
        (onMessage != null ? 1 : 0) +
        (onMakeAdmin != null ? 1 : 0) +
        (onRemoveAdmin != null ? 1 : 0) +
        (onTransferOwnership != null ? 1 : 0) +
        (onMuteMember != null ? 1 : 0) +
        (onBanMember != null ? 1 : 0) +
        (onRemoveMember != null ? 1 : 0);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxMenuHeight = (screenHeight - size.height - 72.0)
        .clamp(106.0, double.infinity)
        .toDouble();
    final estimatedMenuHeight =
        (actionCount * 47.0 + 12).clamp(106.0, maxMenuHeight).toDouble();

    final selectedAction = await Navigator.of(context).push<_GroupMemberAction>(
      MessageContextMenuRoute<_GroupMemberAction>(
        messagePosition: position,
        messageSize: size,
        messageWidget: overlayMemberWidget,
        isMine: false,
        estimatedMenuHeight: estimatedMenuHeight,
        keepAnchorVisible: true,
        menuContentWidget: Builder(
          builder: (menuContext) => _GroupMemberActionMenu(
            isCurrentUser: isCurrentUser,
            canMessage: onMessage != null,
            canMakeAdmin: onMakeAdmin != null,
            canRemoveAdmin: onRemoveAdmin != null,
            canTransferOwnership: onTransferOwnership != null,
            canMuteMember: onMuteMember != null,
            canBanMember: onBanMember != null,
            canRemoveMember: onRemoveMember != null,
            onActionSelected: (action) {
              Navigator.of(menuContext).pop(action);
            },
          ),
        ),
      ),
    );

    if (selectedAction == null) {
      return;
    }

    // Đợi popup đóng trước khi mở dialog / route tiếp theo.
    await Future<void>.delayed(
      const Duration(milliseconds: 80),
    );

    if (!context.mounted) {
      return;
    }

    switch (selectedAction) {
      case _GroupMemberAction.viewProfile:
        onViewProfile();
        break;

      case _GroupMemberAction.message:
        onMessage?.call();
        break;

      case _GroupMemberAction.makeAdmin:
        onMakeAdmin?.call();
        break;

      case _GroupMemberAction.removeAdmin:
        onRemoveAdmin?.call();
        break;

      case _GroupMemberAction.transferOwnership:
        onTransferOwnership?.call();
        break;

      case _GroupMemberAction.mute:
        onMuteMember?.call();
        break;

      case _GroupMemberAction.ban:
        onBanMember?.call();
        break;

      case _GroupMemberAction.remove:
        onRemoveMember?.call();
        break;
    }
  }
}

// ============================================================================
// ACTION TYPE
// ============================================================================

enum _GroupMemberAction {
  viewProfile,
  message,
  makeAdmin,
  removeAdmin,
  transferOwnership,
  mute,
  ban,
  remove,
}

// ============================================================================
// ACTION DATA
// ============================================================================

/// Dùng Widget thay vì IconData.
///
/// Lý do:
/// - CupertinoIcons.xxx là IconData
/// - FontAwesomeIcons.xxx là FaIconData
///
/// Nếu ép cả hai về IconData sẽ lỗi với font_awesome_flutter 11.
/// Cho nên icon được build sẵn thành Widget:
///
/// Icon(CupertinoIcons.xxx)
///
/// hoặc:
///
/// FaIcon(FontAwesomeIcons.xxx)
class _GridActionData {
  final Widget icon;
  final String label;
  final _GroupMemberAction action;
  final Color? textColor;

  const _GridActionData({
    required this.icon,
    required this.label,
    required this.action,
    this.textColor,
  });
}

// ============================================================================
// ACTION MENU
// ============================================================================

class _GroupMemberActionMenu extends StatelessWidget {
  final bool isCurrentUser;

  final bool canMessage;
  final bool canMakeAdmin;
  final bool canRemoveAdmin;
  final bool canTransferOwnership;
  final bool canMuteMember;
  final bool canBanMember;
  final bool canRemoveMember;

  final ValueChanged<_GroupMemberAction> onActionSelected;

  const _GroupMemberActionMenu({
    required this.isCurrentUser,
    required this.canMessage,
    required this.canMakeAdmin,
    required this.canRemoveAdmin,
    required this.canTransferOwnership,
    required this.canMuteMember,
    required this.canBanMember,
    required this.canRemoveMember,

    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;

    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    // ============================================================
    // ACTION LIST
    // ============================================================

    final actions = <_GridActionData>[
      // ----------------------------------------------------------
      // VIEW PROFILE
      // Luôn hiển thị
      // ----------------------------------------------------------

      const _GridActionData(
        icon: Icon(
          CupertinoIcons.person_fill,
          size: 20,
        ),
        label: 'Trang cá nhân',
        action: _GroupMemberAction.viewProfile,
      ),

      // ----------------------------------------------------------
      // MESSAGE
      // Không nhắn tin với chính mình
      // ----------------------------------------------------------

      if (!isCurrentUser && canMessage)
        const _GridActionData(
          icon: Icon(
            CupertinoIcons.chat_bubble_fill,
            size: 20,
          ),
          label: 'Nhắn tin',
          action: _GroupMemberAction.message,
        ),

      // ----------------------------------------------------------
      // MAKE ADMIN
      // ----------------------------------------------------------

      if (!isCurrentUser && canMakeAdmin)
        const _GridActionData(
          icon: Icon(
            CupertinoIcons.star_fill,
            size: 20,
            color: Colors.purple,
          ),
          label: 'Đặt Phó nhóm',
          action: _GroupMemberAction.makeAdmin,
        ),

      // ----------------------------------------------------------
      // REMOVE ADMIN
      // ----------------------------------------------------------

      if (!isCurrentUser && canRemoveAdmin)
        const _GridActionData(
          icon: Icon(
            CupertinoIcons.star_slash,
            size: 20,
            color: Colors.orange,
          ),
          label: 'Gỡ Phó nhóm',
          action: _GroupMemberAction.removeAdmin,
        ),

      // ----------------------------------------------------------
      // TRANSFER OWNER
      //
      // QUAN TRỌNG:
      // FontAwesome dùng FaIcon, KHÔNG dùng Icon.
      // ----------------------------------------------------------

      if (!isCurrentUser && canTransferOwnership)
        const _GridActionData(
          icon: FaIcon(
            FontAwesomeIcons.crown,
            size: 20,
            color: Colors.amber,
          ),
          label: 'Chuyển Owner',
          action: _GroupMemberAction.transferOwnership,
        ),

      // ----------------------------------------------------------
      // MUTE
      // ----------------------------------------------------------

      if (!isCurrentUser && canMuteMember)
        const _GridActionData(
          icon: Icon(
            CupertinoIcons.speaker_slash_fill,
            size: 20,
            color: Colors.orange,
          ),
          label: 'Hạn chế',
          action: _GroupMemberAction.mute,
        ),

      // ----------------------------------------------------------
      // BAN
      // ----------------------------------------------------------

      if (!isCurrentUser && canBanMember)
        const _GridActionData(
          icon: Icon(
            CupertinoIcons.nosign,
            size: 20,
            color: Colors.red,
          ),
          label: 'Cấm',
          action: _GroupMemberAction.ban,
          textColor: Colors.red,
        ),

      // ----------------------------------------------------------
      // REMOVE
      // ----------------------------------------------------------

      if (!isCurrentUser && canRemoveMember)
        const _GridActionData(
          icon: Icon(
            CupertinoIcons.person_badge_minus,
            size: 20,
            color: Colors.red,
          ),
          label: 'Xóa khỏi nhóm',
          action: _GroupMemberAction.remove,
          textColor: Colors.red,
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 290,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.38 : 0.18,
              ),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _ActionList(
          actions: actions,
          dividerColor: dividerColor,
          onActionSelected: onActionSelected,
        ),
      ),
    );
  }
}

// ============================================================================
// VERTICAL ACTION LIST
// ============================================================================

class _ActionList extends StatelessWidget {
  final List<_GridActionData> actions;
  final Color dividerColor;
  final ValueChanged<_GroupMemberAction> onActionSelected;

  const _ActionList({
    required this.actions,
    required this.dividerColor,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Usually every action fits without scrolling. Scrolling is only a
    // fallback for very short screens or large accessibility text sizes.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.70;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              _ActionListItem(
                icon: actions[index].icon,
                label: actions[index].label,
                textColor: actions[index].textColor,
                onTap: () => onActionSelected(actions[index].action),
              ),
              if (index < actions.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 58,
                  color: dividerColor,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// VERTICAL ACTION ITEM
// ============================================================================

class _ActionListItem extends StatelessWidget {
  /// Widget thay vì IconData.
  ///
  /// Nhờ vậy hỗ trợ đồng thời:
  /// - Icon(CupertinoIcons.xxx)
  /// - Icon(Icons.xxx)
  /// - FaIcon(FontAwesomeIcons.xxx)
  final Widget icon;

  final String label;

  final VoidCallback onTap;

  final Color? textColor;

  const _ActionListItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final foregroundColor = isDark ? Colors.white70 : Colors.black54;
    final labelColor = isDark ? Colors.white : Colors.black87;
    final effectiveColor = textColor ?? labelColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: IconTheme(
                  data: IconThemeData(
                    size: 20,
                    color: foregroundColor,
                  ),
                  child: icon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: effectiveColor,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: foregroundColor.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
