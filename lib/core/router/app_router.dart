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

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/feed',
    redirect: (context, state) {
      final isLoggedIn = authState.when(
        data: (s) => s.session != null,
        loading: () => null,
        error: (_, __) => false,
      );

      if (isLoggedIn == null) return null; // still loading

      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/feed';
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),

      // Search (push, no bottom nav)
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SearchScreen(),
      ),

      // Edit profile
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const EditProfileScreen(),
      ),

      // Account Settings
      GoRoute(
        path: '/settings/account',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const AccountSettingsScreen(),
      ),

      // Create Post (Fullscreen modal)
      GoRoute(
          path: '/create',
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) => const CupertinoPage(
                fullscreenDialog: true,
                child: CreatePostScreen(),
              )),

      GoRoute(
        path: '/chat/:conversationId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            ChatScreen(conversationId: state.pathParameters['conversationId']!),
      ),

      // Post detail (outside shell)
      GoRoute(
        path: '/feed/post/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),


      // Main shell (bottom nav)
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
          
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

          GoRoute(
              path: '/chat',
              builder: (_, __) => const ConversationsScreen()),

          GoRoute(
              path: '/notifications',
              builder: (_, __) => const NotificationScreen()),
        ],
      ),

      // Profile (me - outside shell)
      GoRoute(
        path: '/profile/me',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) {
          return Consumer(
            builder: (context, ref, _) {
              final userId = ref.watch(currentUserIdProvider) ?? '';
              return ProfileScreen(userId: userId, isMe: true);
            },
          );
        },
      ),

      // Profile (outside shell — other users)
      GoRoute(
        path: '/profile/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            ProfileScreen(userId: state.pathParameters['userId']!),
      ),
    ],
  );
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const MainShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _selectedIndex(String location) {
    if (location.startsWith('/feed')) return 0;
    if (location.startsWith('/chat')) return 1;
    if (location.startsWith('/create')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/settings') || location.startsWith('/profile/me')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final selectedIndex = _selectedIndex(widget.location);

    return NotificationListener<OpenDrawerNotification>(
      onNotification: (_) {
        _scaffoldKey.currentState?.openDrawer();
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const FeedDrawer(),
        body: widget.child,
        bottomNavigationBar: CupertinoTabBar(
        currentIndex: selectedIndex,
        activeColor: AppColors.primary,
        inactiveColor: AppColors.textHint,
        backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.4,
          ),
        ),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/feed');
              break;
            case 1:
              context.go('/chat');
              break;
            case 2:
              context.push('/create');
              break;
            case 3:
              context.go('/notifications');
              break;
            case 4:
              context.go('/settings');
              break;
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Trang chủ',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2),
            activeIcon: Icon(CupertinoIcons.chat_bubble_2_fill),
            label: 'Tin nhắn',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.plus_circle),
            activeIcon: Icon(CupertinoIcons.plus_circle_fill),
            label: 'Đăng bài',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(CupertinoIcons.bell),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(CupertinoIcons.bell_fill),
            ),
            label: 'Thông báo',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            activeIcon: Icon(CupertinoIcons.settings_solid),
            label: 'Cài đặt',
          ),
        ],
      ),
    ),
    );
  }
}
