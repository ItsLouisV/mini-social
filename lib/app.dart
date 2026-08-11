import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/localization/locale_provider.dart';
import 'features/call/domain/call_model.dart';
import 'features/call/providers/call_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/chat/data/local_chat_repository_exports.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/auth/providers/auth_provider.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class VioraApp extends ConsumerStatefulWidget {
  const VioraApp({super.key});

  @override
  ConsumerState<VioraApp> createState() => _VioraAppState();
}

class _VioraAppState extends ConsumerState<VioraApp>
    with WidgetsBindingObserver {
  bool _isShowingIncomingCall = false;
  Timer? _presenceHeartbeat;
  String? _presenceUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPresence(Supabase.instance.client.auth.currentUser?.id);
    });

    ref.listenManual<AsyncValue<CallModel?>>(incomingCallProvider,
        (prev, next) async {
      final call = next.valueOrNull;

      if (call == null) {
        _isShowingIncomingCall = false;
        return;
      }

      if (_isShowingIncomingCall) return;
      if (call.status != CallStatus.ringing) return;

      _isShowingIncomingCall = true;

      String callerName = 'Cuộc gọi đến';
      String? avatarUrl;
      try {
        final callerProfile =
            await ref.read(profileRepositoryProvider).getProfile(call.callerId);
        callerName = callerProfile.displayName;
        avatarUrl = callerProfile.avatarUrl;
      } catch (_) {
        // A profile/network failure must not hide an otherwise valid call.
      }
      if (!mounted) return;
      final router = ref.read(appRouterProvider);
      router.push('/call/incoming', extra: {
        'callModel': call,
        'callerName': callerName,
        'avatarUrl': avatarUrl,
        'isVideo': call.type == CallType.video,
      });
    });

    ref.listenManual<AsyncValue<AuthState>>(authStateProvider,
        (prev, next) async {
      final prevUser = prev?.valueOrNull?.session?.user;
      final nextUser = next.valueOrNull?.session?.user;

      if (prevUser?.id != nextUser?.id) {
        if (prevUser != null) {
          await ref
              .read(upstashRedisServiceProvider)
              .setUserOffline(prevUser.id);
        }
        _startPresence(nextUser?.id);
      }

      if (nextUser == null && prevUser != null) {
        final localRepo = ref.read(localChatRepositoryProvider);
        if (localRepo != null) {
          try {
            await localRepo.clearAll();
          } catch (e) {
            debugPrint('Failed to clear local DB on signout: $e');
          }
        }
      }
    });

    ref.listenManual<bool>(sessionExpiredProvider, (prev, next) {
      if (next == true) {
        ref.read(sessionExpiredProvider.notifier).state = false;
        final context = ref
            .read(appRouterProvider)
            .routerDelegate
            .navigatorKey
            .currentContext;
        if (context != null && context.mounted) {
          showCupertinoDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Phiên đăng nhập hết hạn'),
              content: const Text(
                  'Phiên đăng nhập của bạn đã hết hạn hoặc không hợp lệ. Vui lòng đăng nhập lại.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Đồng ý'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          );
        }
      }
    });
  }

  void _startPresence(String? userId) {
    _presenceHeartbeat?.cancel();
    _presenceUserId = userId;
    if (userId == null || userId.isEmpty) return;

    final redis = ref.read(upstashRedisServiceProvider);
    unawaited(redis.setUserOnline(userId));
    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(redis.setUserOnline(userId));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final userId = _presenceUserId;
    if (state == AppLifecycleState.resumed) {
      _startPresence(
        userId ?? Supabase.instance.client.auth.currentUser?.id,
      );
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _presenceHeartbeat?.cancel();
      if (userId != null) {
        unawaited(
          ref.read(upstashRedisServiceProvider).setUserOffline(userId),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presenceHeartbeat?.cancel();
    final userId = _presenceUserId;
    if (userId != null) {
      unawaited(
        ref.read(upstashRedisServiceProvider).setUserOffline(userId),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'MiniSocial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppDarkTheme.dark,
      themeMode: themeMode,
      locale: locale,
      routerConfig: router,
      scrollBehavior: MyCustomScrollBehavior(),
      builder: (context, child) {
        return CupertinoTheme(
          data: CupertinoThemeData(
            brightness: Theme.of(context).brightness,
            primaryColor: CupertinoColors.systemBlue,
            scaffoldBackgroundColor:
                CupertinoColors.systemGroupedBackground.resolveFrom(context),
            textTheme: CupertinoTextThemeData(
              textStyle: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
