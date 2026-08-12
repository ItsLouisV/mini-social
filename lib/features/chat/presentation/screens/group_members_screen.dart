
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/toast_service.dart';
import '../../../../shared/widgets/app_avatar.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../domain/conversation_member_model.dart';
import '../../providers/chat_provider.dart';
import '../widgets/group_member_actions.dart';

class GroupMembersScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupMembersScreen({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<GroupMembersScreen> createState() =>
      _GroupMembersScreenState();
}

class _GroupMembersScreenState
    extends ConsumerState<GroupMembersScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SORT MEMBERS
  // Owner -> Admin -> Member
  // ============================================================

  List<ConversationMemberModel> _sortMembers(
    List<ConversationMemberModel> members,
  ) {
    final sorted = [...members];

    int priority(ConversationMemberModel member) {
      if (member.isOwner) return 0;
      if (member.isCoAdmin) return 1;
      return 2;
    }

    sorted.sort((a, b) {
      final roleCompare =
          priority(a).compareTo(priority(b));

      if (roleCompare != 0) {
        return roleCompare;
      }

      final nameA =
          a.profile?.displayName.toLowerCase() ?? '';

      final nameB =
          b.profile?.displayName.toLowerCase() ?? '';

      return nameA.compareTo(nameB);
    });

    return sorted;
  }

  // ============================================================
  // SEARCH MEMBERS
  // ============================================================

  List<ConversationMemberModel> _filterMembers(
    List<ConversationMemberModel> members,
  ) {
    final query =
        _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return members;
    }

    return members.where((member) {
      final name =
          member.profile?.displayName.toLowerCase() ?? '';

      final username =
          member.profile?.username.toLowerCase() ?? '';

      return name.contains(query) ||
          username.contains(query);
    }).toList();
  }

  // ============================================================
  // REFRESH MEMBERS
  // ============================================================

  void _refreshMembers() {
    ref.invalidate(
      groupMembersProvider(
        widget.conversationId,
      ),
    );

    ref.invalidate(
      groupMemberMeProvider(
        widget.conversationId,
      ),
    );

    ref.invalidate(conversationsProvider);
  }

  // ============================================================
  // MEMBER ACTIONS
  // ============================================================

  void _showMemberActions({
    required ConversationMemberModel member,
    required GlobalKey itemKey,
    required bool isMe,
    required bool isOwner,
    required bool isGroupAdmin,
  }) {
    HapticFeedback.mediumImpact();

    GroupMemberActions.show(
      context: context,
      member: member,
      itemKey: itemKey,

      isCurrentUser: isMe,
      currentUserIsOwner: isOwner,
      currentUserIsAdmin: isGroupAdmin,

      // ----------------------------------------------------------
      // VIEW PROFILE
      // ----------------------------------------------------------

      onViewProfile: () {
        context.push(
          '/profile/${member.userId}',
        );
      },

      // ----------------------------------------------------------
      // MESSAGE
      // ----------------------------------------------------------

      onMessage: !isMe
          ? () async {
              try {
                final chatRepo =
                    ref.read(chatRepositoryProvider);

                final directConv =
                    await chatRepo
                        .getOrCreateConversation(
                  member.userId,
                );

                if (!mounted) return;

                context.push(
                  '/chat/${directConv.id}',
                );
              } catch (e) {
                if (!mounted) return;

                ToastService.showError(
                  context,
                  'Không thể mở cuộc trò chuyện: $e',
                );
              }
            }
          : null,

      // ----------------------------------------------------------
      // MAKE ADMIN
      // Chỉ Owner -> Member thường
      // ----------------------------------------------------------

      onMakeAdmin: isOwner &&
              !isMe &&
              !member.isOwner &&
              !member.isCoAdmin
          ? () async {
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .updateMemberRole(
                      widget.conversationId,
                      member.userId,
                      'admin',
                    );

                _refreshMembers();

                if (!mounted) return;

                ToastService.showSuccess(
                  context,
                  'Đã thăng cấp làm Phó nhóm',
                );
              } catch (e) {
                if (!mounted) return;

                ToastService.showError(
                  context,
                  'Lỗi thay đổi quyền: $e',
                );
              }
            }
          : null,

      // ----------------------------------------------------------
      // REMOVE ADMIN
      // Chỉ Owner -> Admin
      // ----------------------------------------------------------

      onRemoveAdmin: isOwner &&
              !isMe &&
              !member.isOwner &&
              member.isCoAdmin
          ? () async {
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .updateMemberRole(
                      widget.conversationId,
                      member.userId,
                      'member',
                    );

                _refreshMembers();

                if (!mounted) return;

                ToastService.showSuccess(
                  context,
                  'Đã gỡ quyền Phó nhóm',
                );
              } catch (e) {
                if (!mounted) return;

                ToastService.showError(
                  context,
                  'Lỗi thay đổi quyền: $e',
                );
              }
            }
          : null,

      // ----------------------------------------------------------
      // MUTE MEMBER
      // Owner/Admin -> người khác, không áp dụng Owner
      // ----------------------------------------------------------

      onMuteMember: isGroupAdmin &&
              !isMe &&
              !member.isOwner &&
              (isOwner || !member.isCoAdmin)
          ? () {
              _showMuteDurationPicker(
                member,
              );
            }
          : null,

      // ----------------------------------------------------------
      // TRANSFER OWNERSHIP
      // Chỉ Owner
      // ----------------------------------------------------------

      onTransferOwnership: isOwner &&
              !isMe &&
              !member.isOwner
          ? () {
              _confirmTransferOwnership(
                member,
              );
            }
          : null,

      // ----------------------------------------------------------
      // BAN MEMBER
      // Chỉ Owner
      // ----------------------------------------------------------

      onBanMember: isOwner &&
              !isMe &&
              !member.isOwner
          ? () {
              _confirmBanMember(
                member,
              );
            }
          : null,

      // ----------------------------------------------------------
      // REMOVE MEMBER
      // Owner/Admin -> người khác, không xóa Owner
      // ----------------------------------------------------------

      onRemoveMember: isGroupAdmin &&
              !isMe &&
              !member.isOwner &&
              (isOwner || !member.isCoAdmin)
          ? () {
              _confirmRemoveMember(
                member,
              );
            }
          : null,
    );
  }

  // ============================================================
  // REMOVE MEMBER
  // ============================================================

  void _confirmRemoveMember(
    ConversationMemberModel member,
  ) {
    final name =
        member.profile?.displayName ?? 'Thành viên';

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(
            'Xóa $name khỏi nhóm?',
          ),
          content: const Text(
            'Thành viên này sẽ bị xóa khỏi nhóm trò chuyện.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Hủy'),
            ),

            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  await ref
                      .read(chatRepositoryProvider)
                      .removeGroupMember(
                        widget.conversationId,
                        member.userId,
                      );

                  _refreshMembers();

                  if (!mounted) return;

                  ToastService.showSuccess(
                    context,
                    'Đã xóa $name khỏi nhóm',
                  );
                } catch (e) {
                  if (!mounted) return;

                  ToastService.showError(
                    context,
                    'Lỗi xóa thành viên: $e',
                  );
                }
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MUTE MEMBER
  // ============================================================

  void _showMuteDurationPicker(
    ConversationMemberModel member,
  ) {
    final name =
        member.profile?.displayName ?? 'Thành viên';

    final durations = <(String, Duration?)>[
      (
        '1 giờ',
        const Duration(hours: 1),
      ),
      (
        '8 giờ',
        const Duration(hours: 8),
      ),
      (
        '24 giờ',
        const Duration(hours: 24),
      ),
      (
        '7 ngày',
        const Duration(days: 7),
      ),
      (
        'Vĩnh viễn',
        null,
      ),
    ];

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(
            'Tắt tiếng $name',
          ),
          content: const Text(
            'Chọn thời gian tắt tiếng:',
          ),
          actions: [
            ...durations.map(
              (entry) {
                return CupertinoDialogAction(
                  onPressed: () async {
                    Navigator.pop(
                      dialogContext,
                    );

                    final duration =
                        entry.$2;

                    final mutedUntil =
                        duration == null
                            ? null
                            : DateTime.now().add(
                                duration,
                              );

                    try {
                      await ref
                          .read(
                            chatRepositoryProvider,
                          )
                          .muteMemberByAdmin(
                            widget.conversationId,
                            member.userId,
                            mutedUntil:
                                mutedUntil,
                          );

                      _refreshMembers();

                      if (!mounted) return;

                      ToastService.showSuccess(
                        context,
                        'Đã tắt tiếng $name (${entry.$1})',
                      );
                    } catch (e) {
                      if (!mounted) return;

                      ToastService.showError(
                        context,
                        'Lỗi tắt tiếng: $e',
                      );
                    }
                  },
                  child: Text(
                    entry.$1,
                  ),
                );
              },
            ),

            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Hủy',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BAN MEMBER
  // ============================================================

  void _confirmBanMember(
    ConversationMemberModel member,
  ) {
    final name =
        member.profile?.displayName ?? 'Thành viên';

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(
            'Cấm $name khỏi nhóm?',
          ),
          content: const Text(
            'Thành viên này sẽ bị xóa khỏi nhóm và không thể tham gia lại.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Hủy',
              ),
            ),

            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(
                  dialogContext,
                );

                try {
                  await ref
                      .read(chatRepositoryProvider)
                      .banMember(
                        widget.conversationId,
                        member.userId,
                      );

                  _refreshMembers();

                  ref.invalidate(
                    groupBansProvider(
                      widget.conversationId,
                    ),
                  );

                  if (!mounted) return;

                  ToastService.showSuccess(
                    context,
                    'Đã cấm $name khỏi nhóm',
                  );
                } catch (e) {
                  if (!mounted) return;

                  ToastService.showError(
                    context,
                    'Lỗi cấm thành viên: $e',
                  );
                }
              },
              child: const Text(
                'Cấm',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // TRANSFER OWNERSHIP
  // ============================================================

  void _confirmTransferOwnership(
    ConversationMemberModel member,
  ) {
    final name =
        member.profile?.displayName ?? 'Thành viên';

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(
            'Chuyển quyền cho $name?',
          ),
          content: Text(
            '$name sẽ trở thành Trưởng nhóm mới. '
            'Bạn sẽ trở thành Phó nhóm.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Hủy',
              ),
            ),

            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.pop(
                  dialogContext,
                );

                try {
                  await ref
                      .read(chatRepositoryProvider)
                      .transferOwnership(
                        widget.conversationId,
                        member.userId,
                      );

                  _refreshMembers();

                  if (!mounted) return;

                  ToastService.showSuccess(
                    context,
                    'Đã chuyển quyền Owner cho $name',
                  );
                } catch (e) {
                  if (!mounted) return;

                  ToastService.showError(
                    context,
                    'Lỗi chuyển quyền: $e',
                  );
                }
              },
              child: const Text(
                'Xác nhận',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MEMBER ITEM
  // ============================================================

  Widget _buildMemberItem({
    required ConversationMemberModel member,
    required bool isMe,
    required bool isOwner,
    required bool isGroupAdmin,
    required Color dividerColor,
    required bool showDivider,
  }) {
    final itemKey = GlobalKey();

    return Column(
      children: [
        ListTile(
          key: itemKey,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),

          leading: AppAvatar(
            imageUrl:
                member.profile?.avatarUrl,
            name:
                member.profile?.displayName ??
                    'Thành viên',
            radius: 22,
          ),

          title: Row(
            children: [
              Flexible(
                child: Text(
                  isMe
                      ? '${member.profile?.displayName ?? "Tôi"} (Tôi)'
                      : member.profile
                              ?.displayName ??
                          'Thành viên',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              if (member.isOwner)
                _buildOwnerBadge()
              else if (member.isCoAdmin)
                _buildAdminBadge(),
            ],
          ),

          subtitle: Padding(
            padding:
                const EdgeInsets.only(top: 2),
            child: Text(
              member.profile?.username !=
                          null &&
                      member.profile!.username
                          .isNotEmpty
                  ? '@${member.profile!.username}'
                  : 'Thành viên nhóm',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),

          trailing: const Icon(
            CupertinoIcons.ellipsis,
            size: 19,
            color: Colors.grey,
          ),

          onTap: () {
            _showMemberActions(
              member: member,
              itemKey: itemKey,
              isMe: isMe,
              isOwner: isOwner,
              isGroupAdmin:
                  isGroupAdmin,
            );
          },
        ),

        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: dividerColor,
            indent: 76,
          ),
      ],
    );
  }

  // ============================================================
  // OWNER BADGE
  // ============================================================

  Widget _buildOwnerBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.amber
            .withValues(alpha: 0.18),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            '👑',
            style:
                TextStyle(fontSize: 10),
          ),
          SizedBox(width: 2),
          Text(
            'Trưởng nhóm',
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN BADGE
  // ============================================================

  Widget _buildAdminBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.purple
            .withValues(alpha: 0.18),
        borderRadius:
            BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Text(
            '⭐',
            style:
                TextStyle(fontSize: 10),
          ),
          SizedBox(width: 2),
          Text(
            'Phó nhóm',
            style: TextStyle(
              fontSize: 10,
              fontWeight:
                  FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar(
    bool isDark,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12,
      ),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : const Color(0xFFF2F2F7),
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: CupertinoTextField(
          controller:
              _searchController,

          placeholder:
              'Tìm kiếm thành viên',

          placeholderStyle:
              const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),

          prefix: const Padding(
            padding:
                EdgeInsets.only(left: 10),
            child: Icon(
              CupertinoIcons.search,
              size: 18,
              color: Colors.grey,
            ),
          ),

          suffix:
              _searchQuery.isNotEmpty
                  ? CupertinoButton(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                      ),
                      minimumSize:
                          Size.zero,
                      onPressed: () {
                        _searchController
                            .clear();

                        setState(() {
                          _searchQuery =
                              '';
                        });
                      },
                      child: const Icon(
                        CupertinoIcons
                            .clear_circled_solid,
                        size: 17,
                        color:
                            Colors.grey,
                      ),
                    )
                  : null,

          decoration: null,

          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? Colors.white
                : Colors.black,
          ),

          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final isDark =
        theme.brightness ==
            Brightness.dark;

    final backgroundColor =
        isDark
            ? Colors.black
            : const Color(
                0xFFF2F2F7,
              );

    final cardColor =
        isDark
            ? const Color(
                0xFF1E1E2C,
              )
            : Colors.white;

    final dividerColor =
        isDark
            ? Colors.white
                .withValues(
                  alpha: 0.08,
                )
            : Colors.black
                .withValues(
                  alpha: 0.08,
                );

    // ============================================================
    // CURRENT USER
    // ============================================================

    final currentUserId =
        ref.watch(
              currentUserIdProvider,
            ) ??
            '';

    // Member record của chính user hiện tại.
    final myMember =
        ref.watch(
      groupMemberMeProvider(
        widget.conversationId,
      ),
    );

    final isOwner =
        myMember?.isOwner ?? false;

    // Owner cũng được tính là người có quyền quản trị.
    final isGroupAdmin =
        isOwner ||
        (myMember?.isCoAdmin ?? false);

    // ============================================================
    // MEMBERS
    // ============================================================

    final membersAsync =
        ref.watch(
      groupMembersProvider(
        widget.conversationId,
      ),
    );

    return Scaffold(
      backgroundColor:
          backgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,

        backgroundColor:
            backgroundColor,

        surfaceTintColor:
            Colors.transparent,

        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            CupertinoIcons.back,
            size: 24,
          ),
        ),

        title: membersAsync.when(
          data: (members) {
            return Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Text(
                  'Thành viên nhóm',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                Text(
                  '${members.length} thành viên',
                  style:
                      const TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.normal,
                    color: Colors.grey,
                  ),
                ),
              ],
            );
          },

          loading: () =>
              const Text(
            'Thành viên nhóm',
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          error: (error, stack) =>
              const Text(
            'Thành viên nhóm',
            style: TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        centerTitle: true,
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ------------------------------------------------------
            // SEARCH
            // ------------------------------------------------------

            _buildSearchBar(
              isDark,
            ),

            // ------------------------------------------------------
            // MEMBERS LIST
            // ------------------------------------------------------

            Expanded(
              child:
                  membersAsync.when(
                data: (members) {
                  final sortedMembers =
                      _sortMembers(
                    members,
                  );

                  final filteredMembers =
                      _filterMembers(
                    sortedMembers,
                  );

                  // ----------------------------------------------
                  // EMPTY GROUP
                  // ----------------------------------------------

                  if (members.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nhóm chưa có thành viên',
                        style: TextStyle(
                          color:
                              Colors.grey,
                        ),
                      ),
                    );
                  }

                  // ----------------------------------------------
                  // SEARCH EMPTY
                  // ----------------------------------------------

                  if (filteredMembers
                      .isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          Icon(
                            CupertinoIcons
                                .person_2_fill,
                            size: 42,
                            color:
                                Colors.grey,
                          ),

                          SizedBox(
                            height: 10,
                          ),

                          Text(
                            'Không tìm thấy thành viên',
                            style:
                                TextStyle(
                              fontSize:
                                  14,
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ----------------------------------------------
                  // LIST
                  // ----------------------------------------------

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                        groupMembersProvider(
                          widget
                              .conversationId,
                        ),
                      );

                      ref.invalidate(
                        groupMemberMeProvider(
                          widget
                              .conversationId,
                        ),
                      );

                      await ref.read(
                        groupMembersProvider(
                          widget
                              .conversationId,
                        ).future,
                      );
                    },

                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),

                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        12,
                        0,
                        12,
                        24,
                      ),

                      children: [
                        Container(
                          clipBehavior:
                              Clip.antiAlias,

                          decoration:
                              BoxDecoration(
                            color:
                                cardColor,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),

                          child: Column(
                            children:
                                List.generate(
                              filteredMembers
                                  .length,
                              (index) {
                                final member =
                                    filteredMembers[
                                        index];

                                return _buildMemberItem(
                                  member:
                                      member,

                                  isMe:
                                      member.userId ==
                                          currentUserId,

                                  isOwner:
                                      isOwner,

                                  isGroupAdmin:
                                      isGroupAdmin,

                                  dividerColor:
                                      dividerColor,

                                  showDivider:
                                      index <
                                          filteredMembers
                                                  .length -
                                              1,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },

                // ----------------------------------------------
                // LOADING
                // ----------------------------------------------

                loading: () =>
                    const Center(
                  child:
                      CupertinoActivityIndicator(),
                ),

                // ----------------------------------------------
                // ERROR
                // ----------------------------------------------

                error: (
                  error,
                  stack,
                ) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(24),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize
                                .min,
                        children: [
                          const Icon(
                            CupertinoIcons
                                .exclamationmark_circle,
                            size: 40,
                            color:
                                Colors.grey,
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          const Text(
                            'Không thể tải danh sách thành viên',
                            style:
                                TextStyle(
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            '$error',
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                const TextStyle(
                              fontSize:
                                  12,
                              color:
                                  Colors.grey,
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          CupertinoButton(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  18,
                              vertical: 8,
                            ),
                            color:
                                AppColors
                                    .primary,
                            onPressed: () {
                              ref.invalidate(
                                groupMembersProvider(
                                  widget
                                      .conversationId,
                                ),
                              );

                              ref.invalidate(
                                groupMemberMeProvider(
                                  widget
                                      .conversationId,
                                ),
                              );
                            },
                            child:
                                const Text(
                              'Thử lại',
                              style:
                                  TextStyle(
                                fontSize:
                                    13,
                              ),
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
    );
  }
}
