import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'core/errors/global_error_handler.dart';
import 'core/services/logger_service.dart';
import 'core/services/objectbox_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    CoreLogger.warning('Failed to load $envFile. Falling back to default .env: $e', tag: 'Bootstrap');
    try {
      await dotenv.load(fileName: '.env');
      CoreLogger.info('Loaded fallback environment config: .env', tag: 'Bootstrap');
    } catch (err) {
      CoreLogger.error('Failed to load any environment config: $err', tag: 'Bootstrap');
    }
  }

  // Initialize Supabase
  try {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || anonKey.isEmpty) {
      throw const FormatException('Supabase URL or Anon Key is missing in environment variables');
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
    CoreLogger.info('Successfully initialized Supabase.', tag: 'Bootstrap');
  } catch (e) {
    CoreLogger.error('Failed to initialize Supabase: $e', tag: 'Bootstrap');
  }

  // Initialize timeago
  timeago.setLocaleMessages('vi', timeago.ViMessages());

  // Initialize ObjectBox on mobile/desktop
  ObjectBoxService? objectBox;
  if (!kIsWeb) {
    try {
      objectBox = await ObjectBoxService.init();
      CoreLogger.info('Successfully initialized ObjectBox database.', tag: 'Bootstrap');
    } catch (e) {
      CoreLogger.error('Failed to initialize ObjectBox: $e', tag: 'Bootstrap');
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (objectBox != null)
          objectBoxProvider.overrideWithValue(objectBox),
      ],
      child: const MiniSocialApp(),
    ),
  );
}
