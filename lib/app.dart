import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/call/domain/call_model.dart';
import 'features/call/providers/call_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/chat/data/local_chat_repository_exports.dart';
import 'features/auth/providers/auth_provider.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class MiniSocialApp extends ConsumerStatefulWidget {
  const MiniSocialApp({super.key});

  @override
  ConsumerState<MiniSocialApp> createState() => _MiniSocialAppState();
}

class _MiniSocialAppState extends ConsumerState<MiniSocialApp> {
  bool _isShowingIncomingCall = false;

  @override
  void initState() {
    super.initState();

    ref.listenManual<AsyncValue<CallModel?>>(incomingCallProvider, (prev, next) async {
      final call = next.valueOrNull;

      if (call == null) {
        _isShowingIncomingCall = false;
        return;
      }

      if (_isShowingIncomingCall) return;
      if (call.status != CallStatus.ringing) return;

      _isShowingIncomingCall = true;

      try {
        final callerProfile = await ref.read(profileRepositoryProvider).getProfile(call.callerId);
        final router = ref.read(appRouterProvider);
        router.push('/call/incoming', extra: {
          'callModel': call,
          'callerName': callerProfile.displayName,
          'avatarUrl': callerProfile.avatarUrl,
          'isVideo': call.type == CallType.video,
        });
      } catch (_) {
        _isShowingIncomingCall = false;
      }
    });

    ref.listenManual<AsyncValue<AuthState>>(authStateProvider, (prev, next) async {
      final prevUser = prev?.valueOrNull?.session?.user;
      final nextUser = next.valueOrNull?.session?.user;

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
        final context = ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          showCupertinoDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('Phiên đăng nhập hết hạn'),
              content: const Text('Phiên đăng nhập của bạn đã hết hạn hoặc không hợp lệ. Vui lòng đăng nhập lại.'),
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

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MiniSocial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppDarkTheme.dark,
      themeMode: themeMode,
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