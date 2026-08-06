import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../utils/notifications.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/device_management_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/providers/chat_provider.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/chat/presentation/screens/hidden_conversations_screen.dart';
import '../../features/chat/presentation/screens/conversation_settings_screen.dart';
import '../../features/chat/presentation/screens/shared_media_screen.dart';
import '../../features/chat/presentation/screens/wallpaper_history_screen.dart';
import '../../features/feed/domain/post_model.dart';
import '../../features/feed/presentation/widgets/feed_drawer.dart';
import '../../features/feed/presentation/screens/create_post_screen.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/feed/presentation/screens/post_detail_screen.dart';
import '../../features/feed/presentation/screens/trash_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/account_settings_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/privacy_settings_screen.dart';
import '../../features/profile/presentation/screens/language_settings_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/social/presentation/screens/follow_list_screen.dart';
import '../../features/social/presentation/screens/friends_list_screen.dart';
import '../../features/social/presentation/screens/notification_screen.dart';
import '../../features/social/presentation/screens/my_qr_code_screen.dart';
import '../../features/social/presentation/screens/qr_scanner_screen.dart';
import '../../features/social/providers/follow_provider.dart';
import '../../features/call/presentation/screens/call_screens.dart';
import '../../features/feed/providers/feed_provider.dart';

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
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.when(
        data: (s) => s.session != null,
        loading: () => null,
        error: (_, __) => false,
      );

      if (isLoggedIn == null) return null;

      final isSplashRoute = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register') ||
          state.matchedLocation.startsWith('/forgot-password');

      if (isSplashRoute) return null;

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/feed';
      return null;
    },
    routes: [
      // ── Auth routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (_, __) => const CupertinoPage(child: SplashScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnim = Tween<Offset>(
              begin: const Offset(0.0, 1.0), // Slide up from bottom
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            );

            return SlideTransition(
              position: slideAnim,
              child: FadeTransition(
                opacity: fadeAnim,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 320),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, __) =>
            const CupertinoPage(child: ForgotPasswordScreen()),
      ),

      // ── Global routes (pushed over everything) ───────────────────────
      GoRoute(
        path: '/trash',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => const CupertinoPage(child: TrashScreen()),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters['q'];
          return CupertinoPage(child: SearchScreen(initialQuery: query));
        },
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
        path: '/settings/devices',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) =>
            const CupertinoPage(child: DeviceManagementScreen()),
      ),
      GoRoute(
        path: '/settings/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) =>
            const CupertinoPage(child: PrivacySettingsScreen()),
      ),
      GoRoute(
        path: '/settings/language',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) =>
            const CupertinoPage(child: LanguageSettingsScreen()),
      ),
      GoRoute(
        path: '/my-qr',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) =>
            const CupertinoPage(child: MyQrCodeScreen()),
      ),
      GoRoute(
        path: '/qr-scan',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) =>
            const CupertinoPage(child: QrScannerScreen()),
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final editPost = state.extra as PostModel?;
          return CupertinoPage(
            fullscreenDialog: true,
            child: CreatePostScreen(editPost: editPost),
          );
        },
      ),
      GoRoute(
        path: '/chat/hidden',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, __) => const CupertinoPage(
          child: HiddenConversationsScreen(),
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
        path: '/chat/:conversationId/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => CupertinoPage(
          child: ConversationSettingsScreen(
            conversationId: state.pathParameters['conversationId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId/media',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => CupertinoPage(
          child: SharedMediaScreen(
            conversationId: state.pathParameters['conversationId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId/wallpaper-history',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) => CupertinoPage(
          child: WallpaperHistoryScreen(
            conversationId: state.pathParameters['conversationId']!,
          ),
        ),
      ),
      // ── Call routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/call/outgoing',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            fullscreenDialog: true,
            child: OutgoingCallScreen(
              conversationId:  extra['conversationId'] as String? ?? '',
              calleeId:        extra['calleeId']       as String? ?? '',
              calleeName:      extra['calleeName']     as String? ?? '',
              calleeAvatarUrl: extra['avatarUrl']      as String?,
              isVideo:         extra['isVideo']        as bool?   ?? false,
              onCancel:        extra['onCancel']       as VoidCallback?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/call/incoming',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            fullscreenDialog: true,
            child: IncomingCallScreen(
              callModel:       extra['callModel'], // CallModel
              callerName:      extra['callerName'] as String? ?? '',
              callerAvatarUrl: extra['avatarUrl']  as String?,
              isVideo:         extra['isVideo']    as bool?   ?? false,
              onAccept:        extra['onAccept']   as VoidCallback?,
              onDecline:       extra['onDecline']  as VoidCallback?,
            ),
          );
        },
      ),
      GoRoute(
        path: '/call/active',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            fullscreenDialog: true,
            child: ActiveCallScreen(
              callModel:      extra['callModel'], // CallModel
              otherName:      extra['otherName']  as String? ?? '',
              otherAvatarUrl: extra['avatarUrl']  as String?,
              isVideo:        extra['isVideo']    as bool?   ?? false,
              onEnd:          extra['onEnd']      as VoidCallback?,
              prePreparedRoom: extra['prePreparedRoom'],
              preFetchedToken: extra['preFetchedToken'] as String?,
              initialCameraOff: extra['initialCameraOff'] as bool? ?? false,
            ),
          );
        },
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
      GoRoute(
        path: '/profile/:userId/follows',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          return CupertinoPage(
            child: FollowListScreen(
              userId: state.pathParameters['userId']!,
              initialIndex: tab == 'following' ? 1 : 0,
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile/:userId/friends',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          int idx = 0;
          if (tab == 'pending') {
            idx = 1;
          } else if (tab == 'sent') {
            idx = 2;
          }
          return CupertinoPage(
            child: FriendsListScreen(
              userId: state.pathParameters['userId']!,
              initialIndex: idx,
            ),
          );
        },
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
    // Chuyển tab hoặc bấm tab -> mở rộng lại header & tabbar
    ref.read(shellUiStateProvider.notifier).setExpandedMode();

    final branchIndex = index > 2 ? index - 1 : index;
    if (branchIndex == widget.navigationShell.currentIndex) {
      if (branchIndex == 0) {
        final scrollController = ref.read(feedScrollControllerProvider);
        if (scrollController.hasClients) {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          ref.read(postLocalStatesProvider.notifier).clearAll();
          ref.invalidate(feedPostsProvider);
        });
      } else {
        widget.navigationShell.goBranch(branchIndex, initialLocation: true);
      }
    } else {
      widget.navigationShell.goBranch(branchIndex);
    }
  }

  int get _visualIndex {
    final branch = widget.navigationShell.currentIndex;
    return branch >= 2 ? branch + 1 : branch;
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    final pixels = metrics.pixels;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (pixels <= 10) {
        ref.read(shellUiStateProvider.notifier).setExpandedMode();
      } else if (delta > 3) {
        // Vuốt lên để xem bài (scroll xuống) -> ẩn header, thu gọn tabbar
        ref.read(shellUiStateProvider.notifier).setCompactMode();
      } else if (delta < -15) {
        // Vuốt xuống nhanh trong khi drag -> hiện lại header & tabbar
        ref.read(shellUiStateProvider.notifier).setExpandedMode();
      }
    } else if (notification is ScrollEndNotification) {
      final velocity = notification.dragDetails?.primaryVelocity ?? 0;
      if (pixels <= 10) {
        ref.read(shellUiStateProvider.notifier).setExpandedMode();
      } else if (velocity > 550) {
        // Vuốt xuống nhanh với vận tốc mạnh (primaryVelocity > 0) -> hiển thị lại
        ref.read(shellUiStateProvider.notifier).setExpandedMode();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifCount = ref.watch(unreadNotificationsCountProvider);
    final unreadMsgAsync = ref.watch(unreadMessagesCountProvider);
    final unreadMsgCount = unreadMsgAsync.valueOrNull ?? 0;
    final shellUiState = ref.watch(shellUiStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NotificationListener<OpenDrawerNotification>(
      onNotification: (_) {
        _scaffoldKey.currentState?.openDrawer();
        return true;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: const FeedDrawer(),
          extendBody: true,
          body: Stack(
            children: [
              widget.navigationShell,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _IosTabBar(
                  visualIndex: _visualIndex,
                  unreadNotifCount: unreadNotifCount,
                  unreadMsgCount: unreadMsgCount,
                  isDark: isDark,
                  isCompact: shellUiState.isTabBarCompact,
                  onTap: _onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Frosted-Glass Glassmorphism Tab Bar
// ─────────────────────────────────────────────────────────────────────────────
class _IosTabBar extends StatelessWidget {
  final int visualIndex;
  final int unreadNotifCount;
  final int unreadMsgCount;
  final bool isDark;
  final bool isCompact;
  final void Function(int) onTap;

  const _IosTabBar({
    required this.visualIndex,
    required this.unreadNotifCount,
    required this.unreadMsgCount,
    required this.isDark,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final screenWidth = mq.size.width;

    // ── Responsive scale ─────────────────────────────────────────────
    // Reference thiết kế: 390px (iPhone 14 Pro).
    // clamp: 0.72 (iPhone SE ~320px) → 1.5 (desktop/tablet wide)
    final scale = (screenWidth / 390.0).clamp(0.72, 1.5);

    // Padding ngang (thu nhỏ ở compact để tabbar đủ chỗ)
    final hPadExpanded = (28.0 * scale).clamp(12.0, 60.0);
    final hPadCompact  = (54.0 * scale).clamp(24.0, 90.0);

    // Chiều cao tabbar
    final barHeightExpanded = (58.0 * scale).clamp(48.0, 76.0);
    final barHeightCompact  = (43.0 * scale).clamp(36.0, 58.0);

    // Bo góc ngoài
    final outerRadiusExpanded = (28.0 * scale).clamp(18.0, 40.0);
    final outerRadiusCompact  = (20.0 * scale).clamp(14.0, 30.0);

    // Nút + ở giữa
    final fabSizeExpanded     = (36.0 * scale).clamp(28.0, 52.0);
    final fabSizeCompact      = (28.0 * scale).clamp(22.0, 40.0);
    final fabRadiusExpanded   = (11.0 * scale).clamp(7.0,  16.0);
    final fabRadiusCompact    = (8.0  * scale).clamp(5.0,  12.0);
    final fabIconSizeExpanded = (20.0 * scale).clamp(15.0, 28.0);
    final fabIconSizeCompact  = (15.0 * scale).clamp(12.0, 22.0);

    return Padding(
      padding: EdgeInsets.only(
        left: hPadExpanded,
        right: hPadExpanded,
        bottom: bottomInset > 0 ? bottomInset : 14,
      ),
      child: AnimatedScale(
        scale: isCompact ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(outerRadiusExpanded),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              height: barHeightExpanded,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A0B0E).withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(outerRadiusExpanded),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final slotWidth = totalWidth / 5;

                // Pill indicator — tỉ lệ 80% chiều cao container giúp hình elip cao ráo & hiện đại
                final pillWidth = (slotWidth * 0.90).clamp(42.0, slotWidth);
                final pillHeight = (constraints.maxHeight * 0.80).clamp(36.0, 54.0);
                final pillRadius = pillHeight / 2;

                final indicatorLeft =
                    (slotWidth * visualIndex) + (slotWidth - pillWidth) / 2;
                final indicatorTop =
                    (constraints.maxHeight - pillHeight) / 2;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // ── 1. Nền Elip Trượt Qua Trượt Lại (Sliding Active Indicator) ──
                    if (visualIndex != 2)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastOutSlowIn,
                        left: indicatorLeft,
                        top: indicatorTop,
                        width: pillWidth,
                        height: pillHeight,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOutCubic,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(pillRadius),
                          ),
                        ),
                      ),

                    // ── 2. Hàng Tab Icons ──
                    Row(
                      children: [
                        _TabItem(
                          visualIdx: 0,
                          currentVisualIdx: visualIndex,
                          isCompact: isCompact,
                          scale: scale,
                          faIcon: FontAwesomeIcons.house,
                          faActiveIcon: FontAwesomeIcons.house,
                          icon: CupertinoIcons.house,
                          activeIcon: CupertinoIcons.house_fill,
                          label: '',
                          onTap: onTap,
                        ),
                        _TabItem(
                          visualIdx: 1,
                          currentVisualIdx: visualIndex,
                          isCompact: isCompact,
                          scale: scale,
                          icon: CupertinoIcons.bubble_left,
                          activeIcon: CupertinoIcons.bubble_left_fill,
                          label: 'Tin nhắn',
                          badge: unreadMsgCount > 0 ? '$unreadMsgCount' : null,
                          onTap: onTap,
                        ),
                        // ── Centre create button ──
                        Expanded(
                          child: GestureDetector(
                            onTap: () => onTap(2),
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOutCubic,
                                width:  isCompact ? fabSizeCompact  : fabSizeExpanded,
                                height: isCompact ? fabSizeCompact  : fabSizeExpanded,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.secondary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      isCompact
                                          ? fabRadiusCompact
                                          : fabRadiusExpanded),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: isCompact ? 4 : 7,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  CupertinoIcons.plus,
                                  color: Colors.white,
                                  size: isCompact
                                      ? fabIconSizeCompact
                                      : fabIconSizeExpanded,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _TabItem(
                          visualIdx: 3,
                          currentVisualIdx: visualIndex,
                          isCompact: isCompact,
                          scale: scale,
                          icon: CupertinoIcons.bell,
                          activeIcon: CupertinoIcons.bell_fill,
                          label: 'Thông báo',
                          badge:
                              unreadNotifCount > 0 ? '$unreadNotifCount' : null,
                          onTap: onTap,
                        ),
                        _TabItem(
                          visualIdx: 4,
                          currentVisualIdx: visualIndex,
                          isCompact: isCompact,
                          scale: scale,
                          icon: CupertinoIcons.person,
                          activeIcon: CupertinoIcons.person_fill,
                          label: 'Cài đặt',
                          onTap: onTap,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
}

class _TabItem extends StatelessWidget {
  final int visualIdx;
  final int currentVisualIdx;
  final bool isCompact;
  final double scale;
  final dynamic faIcon;
  final dynamic faActiveIcon;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badge;
  final void Function(int) onTap;

  const _TabItem({
    required this.visualIdx,
    required this.currentVisualIdx,
    required this.isCompact,
    required this.scale,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
    this.faIcon,
    this.faActiveIcon,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = visualIdx == currentVisualIdx;
    final color = isActive ? AppColors.primary : AppColors.textHint;
    // Icon size tỉ lệ chuẩn với active elipse indicator (AnimatedScale tự co giãn đồng bộ)
    final iconSize = (21.0 * scale).clamp(17.0, 28.0);

    Widget iconWidget;
    if (faIcon != null && faActiveIcon != null) {
      iconWidget = FaIcon(
        isActive ? faActiveIcon : faIcon,
        key: ValueKey(isActive),
        color: color,
        size: iconSize - 2,
      );
    } else {
      iconWidget = Icon(
        isActive ? activeIcon : icon,
        key: ValueKey(isActive),
        color: color,
        size: iconSize,
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(visualIdx),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: iconWidget,
              ),
              if (badge != null)
                Positioned(
                  right: isCompact ? -7 : -9,
                  top: isCompact ? -3 : -4,
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 9 : 10,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

