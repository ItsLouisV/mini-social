import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/errors/global_error_handler.dart';
import 'core/services/logger_service.dart';
import 'core/services/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Giữ cache ảnh giải mã ở mức vừa phải. Ảnh bài viết độ phân giải cao nếu
  // tích tụ trong GPU có thể làm texture của avatar/chat/settings render đen.
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 180;
  imageCache.maximumSizeBytes = 64 * 1024 * 1024;

  // Khởi tạo bộ bắt lỗi toàn cục
  GlobalErrorHandler.initialize();

  // Xác định môi trường từ build-args (--dart-define=ENV=...)
  const env = String.fromEnvironment('ENV', defaultValue: 'development');
  final envFile = switch (env) {
    'production' => '.env.production',
    'staging' => '.env.staging',
    _ => '.env.development',
  };

  try {
    await dotenv.load(fileName: envFile);
    CoreLogger.info('Loaded environment config: $envFile', tag: 'Bootstrap');
  } catch (e) {
    CoreLogger.warning(
        'Failed to load $envFile. Falling back to default .env: $e',
        tag: 'Bootstrap');
    try {
      await dotenv.load(fileName: '.env');
      CoreLogger.info('Loaded fallback environment config: .env',
          tag: 'Bootstrap');
    } catch (err) {
      CoreLogger.error('Failed to load any environment config: $err',
          tag: 'Bootstrap');
    }
  }

  // Initialize Supabase
  try {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || anonKey.isEmpty) {
      throw const FormatException(
          'Supabase URL or Anon Key is missing in environment variables');
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
    final supabase = Supabase.instance.client;

    // Đồng bộ JWT mới cho Realtime. Phiên có thể được khôi phục từ local storage
    // với access token cũ trước khi socket kết nối.
    var session = supabase.auth.currentSession;
    if (session?.isExpired == true) {
      try {
        session = (await supabase.auth.refreshSession()).session;
      } catch (_) {
        await supabase.auth.signOut(scope: SignOutScope.local);
        session = null;
      }
    }
    if (session != null) {
      supabase.realtime.setAuth(session.accessToken);
    }
    supabase.auth.onAuthStateChange.listen((authState) {
      final refreshedSession = authState.session;
      if (refreshedSession != null) {
        supabase.realtime.setAuth(refreshedSession.accessToken);
      }
    });
    CoreLogger.info('Successfully initialized Supabase.', tag: 'Bootstrap');
  } catch (e) {
    CoreLogger.error('Failed to initialize Supabase: $e', tag: 'Bootstrap');
  }

  // Initialize timeago
  timeago.setLocaleMessages('vi', timeago.ViMessages());

  // Initialize Local Database
  // - On native (mobile/desktop): LocalDatabase.init() opens Isar
  // - On web:                     LocalDatabase.init() opens Hive + IndexedDB
  late final LocalDatabase localDb;
  try {
    localDb = await LocalDatabase.init();
    CoreLogger.info('Successfully initialized local database.',
        tag: 'Bootstrap');
  } catch (e) {
    CoreLogger.error('Failed to initialize local database: $e',
        tag: 'Bootstrap');
    rethrow;
  }

  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(
        ProviderScope(
          overrides: [
            isarServiceProvider.overrideWithValue(localDb),
          ],
          child: const VioraApp(),
        ),
      ),
    );
  } else {
    runApp(
      ProviderScope(
        overrides: [
          isarServiceProvider.overrideWithValue(localDb),
        ],
        child: const VioraApp(),
      ),
    );
  }
}
