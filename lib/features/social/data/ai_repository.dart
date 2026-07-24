import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class AIRepository {
  final SupabaseService _service;

  AIRepository(this._service);

  SupabaseClient get client => _service.client;
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

  /// Gọi AI Service để kiểm duyệt nội dung theo Quy trình 6 bước (6-Stage Moderation Pipeline)
  Future<({bool isSafe, String decision, int riskScore, String reason})> moderateContent({
    String? text,
    String? imageBase64,
    String? imageMimeType,
    String? contentId,
    String? contentType,
    String? userId,
  }) async {
    if ((text == null || text.trim().isEmpty) && imageBase64 == null) {
      return (isSafe: true, decision: 'ALLOW', riskScore: 0, reason: '');
    }
    try {
      final res = await _client.functions.invoke(
        'ai-service',
        body: {
          'action': 'moderate',
          if (text != null && text.trim().isNotEmpty) 'text': text,
          if (imageBase64 != null) 'imageBase64': imageBase64,
          if (imageMimeType != null) 'imageMimeType': imageMimeType,
          if (contentId != null) 'contentId': contentId,
          if (contentType != null) 'contentType': contentType,
          if (userId != null) 'userId': userId,
        },
      );

      if (res.data != null) {
        final isSafe = (res.data['isSafe'] as bool?) ?? true;
        final decision = (res.data['decision'] as String?) ?? 'ALLOW';
        final riskScore = (res.data['riskScore'] as int?) ?? 0;
        final reason = (res.data['reason'] as String?) ?? '';
        return (isSafe: isSafe, decision: decision, riskScore: riskScore, reason: reason);
      }
    } catch (e) {
      debugPrint('AI Moderation error: $e');
    }
    return (isSafe: true, decision: 'ALLOW', riskScore: 0, reason: '');
  }

  /// Gọi AI Service chuyên dụng (media-moderator) để kiểm duyệt Ảnh / Video độc hại
  Future<({bool isSafe, String decision, int riskScore, List<String> violations, String reason})> moderateMedia({
    required String mediaBase64,
    required String mediaMimeType,
    String mediaType = 'image',
  }) async {
    try {
      final res = await _client.functions.invoke(
        'media-moderator',
        body: {
          'mediaBase64': mediaBase64,
          'mediaMimeType': mediaMimeType,
          'mediaType': mediaType,
        },
      );

      if (res.data != null) {
        final isSafe = (res.data['isSafe'] as bool?) ?? true;
        final decision = (res.data['decision'] as String?) ?? 'ALLOW';
        final riskScore = (res.data['riskScore'] as int?) ?? 0;
        final violationsList = (res.data['violations'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        final reason = (res.data['reason'] as String?) ?? '';
        return (
          isSafe: isSafe,
          decision: decision,
          riskScore: riskScore,
          violations: violationsList,
          reason: reason
        );
      }
    } catch (e) {
      debugPrint('Media Moderation error: $e');
    }
    return (isSafe: true, decision: 'ALLOW', riskScore: 0, violations: <String>[], reason: '');
  }

  /// Gửi báo cáo vi phạm lên hệ thống kiểm duyệt động (moderation_reports) qua Edge Function riêng biệt
  Future<bool> submitReport({
    required String reporterId,
    required String contentId,
    required String contentType,
    String? categoryName,
    String? description,
    String? reasonLevel1,
    String? reasonLevel2,
    String? reasonLevel3,
    String? urgencyLevel,
    String? reportScope,
    bool shouldBlockUser = false,
    bool shouldHideContent = false,
    bool shouldDeleteConversation = false,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'report-service',
        body: {
          'reporterId': reporterId,
          'contentId': contentId,
          'contentType': contentType,
          if (categoryName != null) 'categoryName': categoryName,
          if (description != null) 'description': description,
          if (reasonLevel1 != null) 'reasonLevel1': reasonLevel1,
          if (reasonLevel2 != null) 'reasonLevel2': reasonLevel2,
          if (reasonLevel3 != null) 'reasonLevel3': reasonLevel3,
          if (urgencyLevel != null) 'urgencyLevel': urgencyLevel,
          if (reportScope != null) 'reportScope': reportScope,
          'shouldBlockUser': shouldBlockUser,
          'shouldHideContent': shouldHideContent,
          'shouldDeleteConversation': shouldDeleteConversation,
        },
      );

      if (res.data != null && res.data['success'] == true) {
        return true;
      }
    } catch (e) {
      debugPrint('Submit Report error: $e');
    }
    return false;
  }
}

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AIRepository(service);
});
