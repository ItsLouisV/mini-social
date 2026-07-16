import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/logger_service.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/profile_model.dart';
import '../../providers/profile_provider.dart';



class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _updatingPrivate = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    if (currentUserId == null) return const Scaffold(body: SizedBox.shrink());

    final profileAsync = ref.watch(profileProvider(currentUserId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final groupedBg = theme.scaffoldBackgroundColor;
    final cardBg = theme.colorScheme.surface;
    final labelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6C6C70);

    return Scaffold(
      backgroundColor: groupedBg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            leading: CupertinoNavigationBarBackButton(
              color: theme.colorScheme.primary,
              previousPageTitle: 'Cài đặt',
              onPressed: () => context.pop(),
            ),
            largeTitle: const Text(
              'Quyền riêng tư',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: groupedBg.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.0),
                width: 0,
              ),
            ),
          ),

          SliverSafeArea(
            top: false,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Section 1: Chế độ tài khoản ────────────────────
                _SectionLabel(label: 'CHẾ ĐỘ TÀI KHOẢN', color: labelColor),
                _SectionCard(
                  bg: cardBg,
                  child: profileAsync.when(
                    data: (profile) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tài khoản riêng tư',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Chỉ những người bạn chấp nhận kết bạn mới có thể xem thông tin hồ sơ và bài đăng của bạn.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: labelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _updatingPrivate
                              ? const CupertinoActivityIndicator()
                              : CupertinoSwitch(
                                  value: profile.isPrivateProfile,
                                  onChanged: (value) => _togglePrivacy(value, profile),
                                ),
                        ],
                      ),
                    ),
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                // ── Section 2: Tương tác & Hạn chế ─────────────────
                _SectionLabel(label: 'MỐI QUAN HỆ', color: labelColor),
                _SectionCard(
                  bg: cardBg,
                  child: Column(
                    children: [
                      _IosRow(
                        iconBg: Colors.redAccent,
                        icon: CupertinoIcons.slash_circle_fill,
                        title: 'Tài khoản đã chặn',
                        onTap: () => _navigateToBlockedList(context),
                      ),
                      _Divider(color: theme.dividerColor),
                      _IosRow(
                        iconBg: Colors.orange,
                        icon: CupertinoIcons.eye_slash_fill,
                        title: 'Tài khoản đã ẩn bài viết',
                        onTap: () => _navigateToMutedList(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePrivacy(bool value, ProfileModel profile) async {
    setState(() => _updatingPrivate = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: profile.id,
            isPrivateProfile: value,
          );
      ref.invalidate(profileProvider(profile.id));
      CoreLogger.info('Toggled private profile: $value', tag: 'PrivacySettings');
    } catch (e) {
      CoreLogger.error('Failed to toggle private profile: $e', tag: 'PrivacySettings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPrivate = false);
    }
  }

  void _navigateToBlockedList(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const _BlockedUsersPage(),
      ),
    );
  }

  void _navigateToMutedList(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const _MutedUsersPage(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page: Danh sách tài khoản đã chặn
// ─────────────────────────────────────────────────────────────────────────────
class _BlockedUsersPage extends ConsumerWidget {
  const _BlockedUsersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản đã chặn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: blockedUsersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                'Chưa chặn ai.',
                style: TextStyle(color: theme.hintColor),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.displayName,
                  radius: 20,
                ),
                title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('@${user.username}'),
                trailing: TextButton(
                  onPressed: () => _unblock(context, ref, user),
                  child: const Text('Bỏ chặn', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref, ProfileModel user) async {
    try {
      await ref.read(profileRepositoryProvider).unblockUser(user.id);
      ref.invalidate(blockedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã bỏ chặn ${user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi bỏ chặn: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page: Danh sách tài khoản đã ẩn
// ─────────────────────────────────────────────────────────────────────────────
class _MutedUsersPage extends ConsumerWidget {
  const _MutedUsersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutedUsersAsync = ref.watch(mutedUsersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản đã ẩn bài', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: mutedUsersAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                'Chưa ẩn bài đăng của ai.',
                style: TextStyle(color: theme.hintColor),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AppAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.displayName,
                  radius: 20,
                ),
                title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('@${user.username}'),
                trailing: TextButton(
                  onPressed: () => _unmute(context, ref, user),
                  child: const Text('Bỏ ẩn', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Future<void> _unmute(BuildContext context, WidgetRef ref, ProfileModel user) async {
    try {
      await ref.read(profileRepositoryProvider).unmuteUser(user.id);
      ref.invalidate(mutedUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã bỏ ẩn bài của ${user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi bỏ ẩn: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Layout Widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 22, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color bg;
  final Widget child;
  const _SectionCard({required this.bg, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 54,
      endIndent: 0,
      color: color.withValues(alpha: 0.4),
    );
  }
}

class _IosRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  const _IosRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            trailing ??
                (showChevron
                    ? Icon(CupertinoIcons.chevron_forward, size: 16, color: hintColor)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
