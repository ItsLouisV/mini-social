import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../feed/domain/post_model.dart';
import '../../profile/domain/profile_model.dart';

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

  /// Gọi Translate Service để dịch bài viết, bình luận hoặc tin nhắn
  Future<String> translateText(
    String text, {
    required String targetLanguage,
  }) async {
    final originalText = text.trim();

    if (originalText.isEmpty) return text;

    try {
      final response = await _client.functions.invoke(
        'translate-service',
        body: {
          'text': originalText,

          // Chỉ gửi "vi" hoặc "en"
          'targetLanguage': targetLanguage,

          // Có thể dùng cho rate limit
          'userId': _client.auth.currentUser?.id,
        },
      );

      final data = response.data;

      if (data is Map && data['translatedText'] is String) {
        final translatedText = data['translatedText'] as String;

        if (translatedText.trim().isNotEmpty) {
          return translatedText;
        }
      }

      if (data is Map && data['error'] != null) {
        debugPrint('Translate Service error: ${data['error']}');
      }
    } catch (error, stackTrace) {
      debugPrint('AI Translate error: $error');
      debugPrintStack(stackTrace: stackTrace);
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


  /// Gửi báo cáo vi phạm lên hệ thống kiểm duyệt (reports table v2)
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
      String validReason = 'other';
      final r = (reasonLevel1 ?? '').toLowerCase();
      if (r.contains('spam') || r.contains('rác')) validReason = 'spam';
      else if (r.contains('harass') || r.contains('quấy rối')) validReason = 'harassment';
      else if (r.contains('sex') || r.contains('khiêu dâm') || r.contains('nude')) validReason = 'nudity_sexual';
      else if (r.contains('violat') || r.contains('bạo lực')) validReason = 'violence_gore';
      else if (r.contains('hate') || r.contains('thù ghét')) validReason = 'hate_speech';
      else if (r.contains('misinfo') || r.contains('sai sự thật')) validReason = 'misinformation';

      final insertData = <String, dynamic>{
        'content_type': contentType,
        if (contentType == 'post') 'post_id': contentId,
        if (contentType == 'comment') 'comment_id': contentId,
        if (contentType == 'message') 'message_id': contentId,
        'reporter_id': reporterId,
        'reason': validReason,
        if (description != null && description.isNotEmpty) 'description': description,
        'status': 'pending',
      };

      final data = await _client.from('reports').insert(insertData).select('id').single();
      final reportId = data['id'] as String;

      // Trigger process-report Edge Function in background to calculate priority score
      _safeInvokeFunction(
        'process-report',
        body: {
          'report_id': reportId,
        },
      );

      return true;
    } catch (e) {
      debugPrint('Submit Report error: $e');
    }
    return false;
  }

  void _safeInvokeFunction(String functionName, {Map<String, dynamic>? body}) {
    Future(() async {
      try {
        await _client.functions.invoke(functionName, body: body);
      } catch (err) {
        debugPrint('$functionName background error: $err');
      }
    });
  }

  /// Tìm kiếm bài viết bằng AI Semantic + Hybrid Search (RRF)
  Future<List<PostModel>> hybridSearchPosts(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await _client.functions.invoke(
        'ai-service',
        body: {
          'action': 'hybrid_search',
          'text': query.trim(),
        },
      );

      if (res.data != null && res.data['posts'] != null) {
        final List list = res.data['posts'] as List;
        if (list.isEmpty) return [];

        final postIds = list.map((item) => (item['post_id'] ?? item['id']) as String).toList();
        final authorIds = list.map((item) => (item['user_id'] ?? item['userId']) as String).toSet().toList();

        final authorsRes = await _client.from('profiles').select().inFilter('id', authorIds);
        final authorMap = {for (var a in authorsRes) a['id'] as String: ProfileModel.fromJson(a)};

        final mediaRes = await _client.from('post_media').select().inFilter('post_id', postIds).order('order_index');
        final mediaMap = <String, List<PostMedia>>{};
        for (var m in mediaRes) {
          final pid = m['post_id'] as String;
          mediaMap.putIfAbsent(pid, () => []).add(PostMedia.fromJson(m));
        }

        return list.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final pid = (map['post_id'] ?? map['id']) as String;
          final uid = (map['user_id'] ?? map['userId']) as String;
          final createdAtRaw = map['created_at'] ?? map['createdAt'];
          final createdAt = createdAtRaw != null
              ? DateTime.parse(createdAtRaw.toString())
              : DateTime.now();

          return PostModel(
            id: pid,
            userId: uid,
            caption: map['caption'] as String?,
            media: mediaMap[pid] ?? [],
            likesCount: (map['likes_count'] ?? map['likesCount'] ?? 0) as int,
            commentsCount: (map['comments_count'] ?? map['commentsCount'] ?? 0) as int,
            createdAt: createdAt,
            author: authorMap[uid],
            privacy: (map['privacy'] ?? 'public') as String,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('AI Hybrid Search error: $e');
    }
    return [];
  }
  /// Tự động quét bất đồng bộ sau khi đăng bài (Lớp 2 + 3 Async Scan)
  Future<void> triggerAsyncPostScan({
    required String postId,
    required String content,
    required String userId,
    String? imageBase64,
  }) async {
    try {
      await _client.functions.invoke(
        'ai-service',
        body: {
          'action': 'async_post_scan',
          'postId': postId,
          'content': content,
          'userId': userId,
          if (imageBase64 != null) 'imageBase64': imageBase64,
        },
      );
    } catch (e) {
      debugPrint('Async Post Scan error: $e');
    }
  }

  /// Lấy danh sách vi phạm của người dùng
  Future<List<Map<String, dynamic>>> getViolations(String userId) async {
    try {
      final res = await _client
          .from('user_violations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Get Violations error: $e');
      return [];
    }
  }

  /// Lấy danh sách đơn kháng cáo của người dùng
  Future<List<Map<String, dynamic>>> getAppeals(String userId) async {
    try {
      final res = await _client
          .from('appeals')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Get Appeals error: $e');
      return [];
    }
  }

  /// Gửi đơn kháng cáo
  Future<bool> submitAppeal({
    required String userId,
    required String reason,
    String? actionId,
  }) async {
    try {
      await _client.from('appeals').insert({
        'user_id': userId,
        'reason': reason,
        if (actionId != null) 'action_id': actionId,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('Submit Appeal error: $e');
      return false;
    }
  }
}

final aiRepositoryProvider = Provider<AIRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AIRepository(service);
});

