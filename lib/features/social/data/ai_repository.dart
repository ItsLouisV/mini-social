import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AIRepository {
  final SupabaseService _service;

  AIRepository(this._service);

  SupabaseClient get _client => _service.client;

  /// Gọi AI Service để gợi ý Caption (hỗ trợ phân tích ảnh trực tiếp qua Base64)
  Future<String> generateCaption({
    String? textPrompt,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'ai-service',
        body: {
          'action': 'generate_caption',
          if (textPrompt != null) 'text': textPrompt,
          if (imageBase64 != null) 'imageBase64': imageBase64,
          if (imageMimeType != null) 'imageMimeType': imageMimeType,
        },
      );

      if (res.data != null && res.data['caption'] != null) {
        return res.data['caption'] as String;
      }
    } catch (e) {
      debugPrint('AI Caption error: $e');
    }
    return 'Một ngày thật tuyệt vời! ✨ #MiniSocial #LifeMoment';
  }

  /// Gọi AI Service để dịch văn bản
  Future<String> translateText(String text, {String targetLanguage = 'tiếng Việt'}) async {
    if (text.trim().isEmpty) return text;
    try {
      final res = await _client.functions.invoke(
        'ai-service',
        body: {
          'action': 'translate',
          'text': text,
          'targetLanguage': targetLanguage,
        },
      );

      if (res.data != null && res.data['translatedText'] != null) {
        return res.data['translatedText'] as String;
      }
    } catch (e) {
      debugPrint('AI Translate error: $e');
    }
    return text;
  }

  /// Gọi AI Service để kiểm duyệt nội dung độc hại
  Future<({bool isSafe, String reason})> moderateContent(String text) async {
    if (text.trim().isEmpty) return (isSafe: true, reason: '');
    try {
      final res = await _client.functions.invoke(
        'ai-service',
        body: {
          'action': 'moderate',
          'text': text,
        },
      );

      if (res.data != null) {
        final isSafe = (res.data['isSafe'] as bool?) ?? true;
        final reason = (res.data['reason'] as String?) ?? '';
        return (isSafe: isSafe, reason: reason);
      }
    } catch (e) {
      debugPrint('AI Moderation error: $e');
    }
    return (isSafe: true, reason: '');
  }
}

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AIRepository(service);
});
