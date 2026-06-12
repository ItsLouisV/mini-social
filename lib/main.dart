import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'app.dart';
import 'core/services/objectbox_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize timeago
  timeago.setLocaleMessages('vi', timeago.ViMessages());

  // Initialize ObjectBox on mobile/desktop
  ObjectBoxService? objectBox;
  if (!kIsWeb) {
    try {
      objectBox = await ObjectBoxService.init();
    } catch (e) {
      debugPrint('Failed to initialize ObjectBox: $e');
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
