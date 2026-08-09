import 'conversation_member_model.dart';

/// Centralized permission helper for group chat.
///
/// Instantiate once per build from [ConversationMemberModel] + conversation
/// permission settings, then query individual `can*` getters throughout UI.
///
/// Usage:
/// ```dart
/// final perms = GroupPermissions(
///   myMember: myMemberModel,
///   adminOnlyMessaging: conv.adminOnlyMessaging,
///   allowMemberInvite: conv.allowMemberInvite,
///   allowMemberPin: conv.allowMemberPin,
///   allowMemberMentionAll: conv.allowMemberMentionAll,
///   allowMemberEditInfo: conv.allowMemberEditInfo,
/// );
/// if (perms.canSendMessage) { ... }
/// ```
class GroupPermissions {
  final ConversationMemberModel myMember;
  final bool adminOnlyMessaging;
  final bool allowMemberInvite;
  final bool allowMemberPin;
  final bool allowMemberMentionAll;
  final bool allowMemberEditInfo;

  const GroupPermissions({
    required this.myMember,
    this.adminOnlyMessaging = false,
    this.allowMemberInvite = true,
    this.allowMemberPin = true,
    this.allowMemberMentionAll = true,
    this.allowMemberEditInfo = true,
  });

  // ── Convenience shortcuts ─────────────────────────────────────────────────

  bool get isOwner => myMember.isOwner;
  bool get isAdmin => myMember.isAdmin; // owner OR co_admin
  bool get isCoAdmin => myMember.isCoAdmin;
  bool get isMember => myMember.isMember;

  /// True if the member is currently silenced by an admin.
  bool get isMutedByAdmin {
    if (!myMember.isMutedByAdmin) return false;
    // Check if timed mute has expired
    final until = myMember.mutedUntil;
    if (until != null && DateTime.now().isAfter(until)) return false;
    return true;
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  /// Can send text / image messages into the group.
  bool get canSendMessage {
    if (isMutedByAdmin) return false;
    if (adminOnlyMessaging && !isAdmin) return false;
    return true;
  }

  // ── Message actions ───────────────────────────────────────────────────────

  /// Can pin or unpin a message (owner/admin always; member if toggle is on).
  bool get canPinMessage => isAdmin || allowMemberPin;

  /// Can delete / recall someone else's message (only owner/admin).
  bool get canDeleteOthersMessage => isAdmin;

  /// Can use @everyone / @all mention (owner/admin always; member if toggle is on).
  bool get canMentionAll => isAdmin || allowMemberMentionAll;

  // ── Member management ─────────────────────────────────────────────────────

  /// Can invite / add new members to the group.
  bool get canInviteMembers => isAdmin || allowMemberInvite;

  /// Can remove a member from the group (owner/admin only).
  bool get canRemoveMembers => isAdmin;

  /// Can ban a member permanently (owner only).
  bool get canBanMembers => isOwner;

  /// Can mute a member (owner/admin only).
  bool get canMuteMembers => isAdmin;

  // ── Group info ────────────────────────────────────────────────────────────

  /// Can edit group name, avatar, and/or description.
  bool get canEditGroupInfo => isAdmin || allowMemberEditInfo;

  // ── Admin-level settings (owner only) ────────────────────────────────────

  /// Can toggle admin-only messaging mode.
  bool get canToggleAdminOnly => isOwner;

  /// Can change the 6 member permission toggles.
  bool get canChangeMemberPermissions => isOwner;

  /// Can promote a member to co-admin (phó nhóm).
  bool get canPromoteToAdmin => isOwner;

  /// Can demote a co-admin back to member.
  bool get canDemoteAdmin => isOwner;

  /// Can transfer group ownership to another member.
  bool get canTransferOwnership => isOwner;

  /// Can dissolve (delete) the entire group.
  bool get canDissolveGroup => isOwner;

  /// Can leave the group.
  /// Owner can only leave after transferring ownership (enforced in UI).
  bool get canLeaveGroup => true;
}
