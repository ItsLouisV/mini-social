import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/call/domain/call_model.dart';
import 'features/call/providers/call_provider.dart';
import 'features/profile/providers/profile_provider.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

class MiniSocialApp extends ConsumerWidget {
  const MiniSocialApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Lắng nghe cuộc gọi đến
    ref.listen(incomingCallProvider, (prev, next) async {
      final call = next.value;
      if (call != null && call.status == CallStatus.ringing) {
        // Tránh push nhiều lần nếu app rebuild
        final currentLocation = router.routerDelegate.currentConfiguration.uri.toString();
        if (currentLocation.startsWith('/call')) return;

        try {
          final callerProfile = await ref.read(profileRepositoryProvider).getProfile(call.callerId);
          router.push('/call/incoming', extra: {
            'callModel': call,
            'callerName': callerProfile.displayName,
            'avatarUrl': callerProfile.avatarUrl,
            'isVideo': call.type == CallType.video,
          });
        } catch (_) {}
      }
    });

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
