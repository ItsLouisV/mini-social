import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/dark_theme.dart';
import 'core/theme/theme_provider.dart';

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
