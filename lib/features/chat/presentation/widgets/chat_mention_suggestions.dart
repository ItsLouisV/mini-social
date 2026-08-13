import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/conversation_member_model.dart';

class ChatMentionMatch {
  final int start;
  final int end;
  final String query;

  const ChatMentionMatch({
    required this.start,
    required this.end,
    required this.query,
  });

  static ChatMentionMatch? fromValue(TextEditingValue value) {
    final caret = value.selection.baseOffset;
    if (caret < 0 || caret > value.text.length) return null;

    final beforeCaret = value.text.substring(0, caret);
    final match = RegExp(r'(?:^|\s)@([^\s@]*)$').firstMatch(beforeCaret);
    if (match == null) return null;

    final atIndex = beforeCaret.lastIndexOf('@');
    return ChatMentionMatch(
      start: atIndex,
      end: caret,
      query: (match.group(1) ?? '').toLowerCase(),
    );
  }
}

class ChatMentionOption {
  final String token;
  final String title;
  final String subtitle;
  final String? avatarUrl;
  final bool isBroadcast;

  const ChatMentionOption({
    required this.token,
    required this.title,
    required this.subtitle,
    this.avatarUrl,
    this.isBroadcast = false,
  });

  static List<ChatMentionOption> build({
    required List<ConversationMemberModel> members,
    required String currentUserId,
    required bool canMentionAll,
    required String query,
  }) {
    final options = <ChatMentionOption>[
      if (canMentionAll) ...[
        const ChatMentionOption(
          token: 'all',
          title: '@all',
          subtitle: 'Nhắc toàn bộ thành viên trong nhóm',
          isBroadcast: true,
        ),
      ],
      ...members
          .where((member) => member.userId != currentUserId)
          .map((member) {
        final fullName = member.profile?.fullName?.trim();
        final rawUsername = member.profile?.username.trim() ?? '';
        final username = rawUsername.startsWith('@')
            ? rawUsername.substring(1)
            : rawUsername;
        final hasFullName = fullName != null && fullName.isNotEmpty;
        final hasUsername = username.isNotEmpty;
        // Insert the full name first. Username is the fallback when full name
        // is absent or invalid; user id is only a final safety fallback.
        final token = hasFullName
            ? fullName
            : hasUsername
                ? username
                : member.userId;

        return ChatMentionOption(
          token: token,
          title: hasFullName
              ? fullName
              : hasUsername
                  ? username
                  : member.userId,
          subtitle: hasUsername ? '@$username' : 'Chưa có username',
          avatarUrl: member.profile?.avatarUrl,
        );
      }),
    ];

    if (query.isEmpty) return options.take(8).toList();
    return options
        .where((option) {
          return option.token.toLowerCase().contains(query) ||
              option.title.toLowerCase().contains(query) ||
              option.subtitle.toLowerCase().contains(query);
        })
        .take(8)
        .toList();
  }
}

class ChatMentionSuggestions extends StatelessWidget {
  final List<ChatMentionOption> options;
  final Color accentColor;
  final ValueChanged<ChatMentionOption> onSelected;

  const ChatMentionSuggestions({
    super.key,
    required this.options,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
            color: accentColor.withValues(alpha: isDark ? 0.10 : 0.06),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle_fill,
                  size: 15,
                  color: accentColor,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Dùng @all để nhắc toàn bộ thành viên',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: options.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 58,
                color: theme.dividerColor.withValues(alpha: 0.10),
              ),
              itemBuilder: (context, index) {
                final option = options[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: option.isBroadcast
                      ? Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.person_3_fill,
                            color: accentColor,
                            size: 20,
                          ),
                        )
                      : AppAvatar(
                          imageUrl: option.avatarUrl,
                          name: option.title,
                          radius: 19,
                        ),
                  title: Text(
                    option.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: option.title.startsWith('@') ? accentColor : null,
                    ),
                  ),
                  subtitle: Text(
                    option.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: option.subtitle.startsWith('@')
                          ? accentColor.withValues(alpha: 0.85)
                          : theme.hintColor,
                      fontWeight: option.subtitle.startsWith('@')
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
