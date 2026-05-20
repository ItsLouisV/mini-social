import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../utils/notifications.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/feed/presentation/widgets/feed_drawer.dart';
import '../../features/feed/presentation/screens/create_post_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/social/presentation/screens/notification_screen.dart';
import '../../features/social/providers/follow_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _feedTabKey = GlobalKey<NavigatorState>(debugLabel: 'feedTab');
final _chatTabKey = GlobalKey<NavigatorState>(debugLabel: 'chatTab');
final _notifTabKey = GlobalKey<NavigatorState>(debugLabel: 'notifTab');
final _settingsTabKey = GlobalKey<NavigatorState>(debugLabel: 'settingsTab');

class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = RouterRefreshListenable(ref);
  ref.onDispose(() => refreshListenable.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.when(
        data: (s) => s.session != null,
        loading: () => null,
        error: (_, __) => false,
      );

      if (isLoggedIn == null) return null;

      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/feed';
      return null;
    },
    routes: [
      // ── Auth routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (_, __) => const CupertinoPage(child: LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, __) => const CupertinoPage(child: RegisterScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, __) =>
            const CupertinoPage(child: ForgotPasswordScreen()),
      ),

      // ── Global routes (pushed over everything) ───────────────────────
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => const CupertinoPage(child: SearchScreen()),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => const CupertinoPage(
          fullscreenDialog: true,
          child: EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/settings/account',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) =>
            const CupertinoPage(child: AccountSettingsScreen()),
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => const CupertinoPage(
          fullscreenDialog: true,
          child: CreatePostScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => CupertinoPage(
          child: ChatScreen(
            conversationId: state.pathParameters['conversationId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/feed/post/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => CupertinoPage(
          child: PostDetailScreen(postId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/profile/me',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => CupertinoPage(
          child: Consumer(
            builder: (context, ref, _) {
              final userId = ref.watch(currentUserIdProvider) ?? '';
              return ProfileScreen(userId: userId, isMe: true);
            },
          ),
        ),
      ),
      GoRoute(
        path: '/profile/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => CupertinoPage(
          child: ProfileScreen(userId: state.pathParameters['userId']!),
        ),
      ),

      // ── StatefulShellRoute — each tab keeps its own navigator stack ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _feedTabKey,
            routes: [
              GoRoute(
                path: '/feed',
                pageBuilder: (_, __) =>
                    const CupertinoPage(child: FeedScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _chatTabKey,
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (_, __) =>
                    const CupertinoPage(child: ConversationsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _notifTabKey,
            routes: [
              GoRoute(
                path: '/notifications',
                pageBuilder: (_, __) =>
                    const CupertinoPage(child: NotificationScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsTabKey,
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (_, __) =>
                    const CupertinoPage(child: SettingsScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// MainShell
// ─────────────────────────────────────────────────────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onTap(int index) {
    if (index == 2) {
      context.push('/create');
      return;
    }
    // Map visual index → branch index (skip the "+" slot)
    final branchIndex = index > 2 ? index - 1 : index;
    if (branchIndex == widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(branchIndex, initialLocation: true);
    } else {
      widget.navigationShell.goBranch(branchIndex);
    }
  }

  // Convert branch index → visual tab index
  int get _visualIndex {
    final branch = widget.navigationShell.currentIndex;
    return branch >= 2 ? branch + 1 : branch;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NotificationListener<OpenDrawerNotification>(
      onNotification: (_) {
        _scaffoldKey.currentState?.openDrawer();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const FeedDrawer(),
        body: widget.navigationShell,
        bottomNavigationBar: _IosTabBar(
          visualIndex: _visualIndex,
          unreadCount: unreadCount,
          isDark: isDark,
          onTap: _onTap,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS-style frosted-glass tab bar
// ─────────────────────────────────────────────────────────────────────────────
class _IosTabBar extends StatelessWidget {
  final int visualIndex;
  final int unreadCount;
  final bool isDark;
  final void Function(int) onTap;

  const _IosTabBar({
    required this.visualIndex,
    required this.unreadCount,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barBg = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.14),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          child: Row(
            children: [
              _TabItem(
                visualIdx: 0,
                currentVisualIdx: visualIndex,
                icon: CupertinoIcons.house,
                activeIcon: CupertinoIcons.house_fill,
                label: 'Trang chủ',
                onTap: onTap,
              ),
              _TabItem(
                visualIdx: 1,
                currentVisualIdx: visualIndex,
                icon: CupertinoIcons.chat_bubble_2,
                activeIcon: CupertinoIcons.chat_bubble_2_fill,
                label: 'Tin nhắn',
                onTap: onTap,
              ),
              // ── Centre create button ──
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(2),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.plus,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              _TabItem(
                visualIdx: 3,
                currentVisualIdx: visualIndex,
                icon: CupertinoIcons.bell,
                activeIcon: CupertinoIcons.bell_fill,
                label: 'Thông báo',
                badge: unreadCount > 0 ? '$unreadCount' : null,
                onTap: onTap,
              ),
              _TabItem(
                visualIdx: 4,
                currentVisualIdx: visualIndex,
                icon: CupertinoIcons.person_circle,
                activeIcon: CupertinoIcons.person_circle_fill,
                label: 'Cài đặt',
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final int visualIdx;
  final int currentVisualIdx;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
  final void Function(int) onTap;

  const _TabItem({
    required this.visualIdx,
    required this.currentVisualIdx,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = visualIdx == currentVisualIdx;
    final color = isActive ? AppColors.primary : AppColors.textHint;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(visualIdx),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    color: color,
                    size: 25,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -9,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
