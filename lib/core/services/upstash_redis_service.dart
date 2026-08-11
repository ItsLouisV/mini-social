import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class UpstashRedisService {
  final String _restUrl;
  final String _restToken;
  final http.Client _client;

  UpstashRedisService({
    String? restUrl,
    String? restToken,
    http.Client? client,
  })  : _restUrl = restUrl ??
            (dotenv.isInitialized ? dotenv.env['UPSTASH_REDIS_REST_URL'] : null) ??
            'https://stunning-haddock-171324.upstash.io',
        _restToken = restToken ??
            (dotenv.isInitialized ? dotenv.env['UPSTASH_REDIS_REST_TOKEN'] : null) ??
            'gQAAAAAAAp08AAIgcDI4ZWExOTY5NWJmZTY0NzVjYWIxNDc0YmE2NjlkN2EwMw',
        _client = client ?? http.Client();

  bool get isConfigured => _restUrl.isNotEmpty && _restToken.isNotEmpty;

  /// Thực thi một lệnh Redis bằng Upstash REST API
  Future<dynamic> executeCommand(List<dynamic> args) async {
    if (!isConfigured) return null;

    try {
      final response = await _client.post(
        Uri.parse(_restUrl),
        headers: {
          'Authorization': 'Bearer $_restToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(args),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('result')) {
          return decoded['result'];
        }
      } else {
        debugPrint(
            '⚠️ [UpstashRedisService] HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('ℹ️ [UpstashRedisService] Offline - executeCommand skipped: ${e.runtimeType}');
    }
    return null;
  }

  /// Thực thi chuỗi lệnh Pipeline
  Future<List<dynamic>> executePipeline(List<List<dynamic>> commands) async {
    if (!isConfigured || commands.isEmpty) return [];

    try {
      final response = await _client.post(
        Uri.parse('$_restUrl/pipeline'),
        headers: {
          'Authorization': 'Bearer $_restToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(commands),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((item) {
            if (item is Map && item.containsKey('result')) {
              return item['result'];
            }
            return item;
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [UpstashRedisService] Offline - executePipeline skipped: ${e.runtimeType}');
    }
    return [];
  }

  // ── 1. Rate Limiting (5 tin / 15 giây) ───────────────────────────────────

  /// Kiểm tra xem user có bị vọt quá số tin nhắn cho phép hay không
  Future<bool> checkRateLimit(
    String userId, {
    int maxRequests = 5,
    int windowSeconds = 15,
  }) async {
    if (userId.isEmpty) return true;

    final key = 'ratelimit:send_msg:$userId';
    try {
      final currentCount = await executeCommand(['INCR', key]);
      if (currentCount == null) return true; // Fallback nếu Redis lỗi

      final countInt = (currentCount is int)
          ? currentCount
          : int.tryParse(currentCount.toString()) ?? 1;

      // Đặt TTL cho key ở lần đầu tiên tạo
      if (countInt == 1) {
        await executeCommand(['EXPIRE', key, windowSeconds]);
      }

      return countInt <= maxRequests;
    } catch (e) {
      debugPrint('⚠️ [UpstashRedisService] Lỗi checkRateLimit: $e');
      return true; // Cho phép gửi nếu lỗi Redis để không nghẽn UX
    }
  }

  // ── 2. Online / Offline Presence ────────────────────────────────────────

  /// Đặt trạng thái online và đồng thời cập nhật mốc hoạt động gần nhất.
  Future<void> setUserOnline(String userId, {int ttlSeconds = 75}) async {
    if (userId.isEmpty) return;
    await executePipeline([
      ['SET', 'user:online:$userId', 'online', 'EX', ttlSeconds],
      ['SET', 'user:last_active:$userId', DateTime.now().toUtc().millisecondsSinceEpoch],
    ]);
  }

  /// Đặt trạng thái offline và lưu thời điểm hoạt động cuối.
  Future<void> setUserOffline(String userId) async {
    if (userId.isEmpty) return;
    await executePipeline([
      ['DEL', 'user:online:$userId'],
      ['SET', 'user:last_active:$userId', DateTime.now().toUtc().millisecondsSinceEpoch],
    ]);
  }

  /// Kiểm tra một user có online hay không
  Future<bool> isUserOnline(String userId) async {
    if (userId.isEmpty) return false;
    final res = await executeCommand(['GET', 'user:online:$userId']);
    return res != null && res.toString() == 'online';
  }

  /// Lấy cùng lúc trạng thái online và thời điểm hoạt động cuối.
  Future<({bool isOnline, DateTime? lastActive})> getUserPresence(
    String userId,
  ) async {
    if (userId.isEmpty) return (isOnline: false, lastActive: null);

    final results = await executePipeline([
      ['GET', 'user:online:$userId'],
      ['GET', 'user:last_active:$userId'],
    ]);
    final onlineValue = results.isNotEmpty ? results[0] : null;
    final lastActiveValue = results.length > 1 ? results[1] : null;
    final milliseconds = int.tryParse(lastActiveValue?.toString() ?? '');

    return (
      isOnline: onlineValue?.toString() == 'online',
      lastActive: milliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              milliseconds,
              isUtc: true,
            ).toLocal(),
    );
  }

  /// Lấy danh sách trạng thái Online của nhiều user cùng lúc (Pipeline)
  Future<Map<String, bool>> getOnlineUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final commands = userIds.map((id) => ['GET', 'user:online:$id']).toList();
    final results = await executePipeline(commands);

    final resultMap = <String, bool>{};
    for (int i = 0; i < userIds.length; i++) {
      final res = i < results.length ? results[i] : null;
      resultMap[userIds[i]] = res != null && res.toString() == 'online';
    }
    return resultMap;
  }

  // ── 3. Typing Indicators ────────────────────────────────────────────────

  /// Đặt trạng thái đang soạn tin nhắn với TTL (mặc định 3s)
  Future<void> setUserTyping(
    String conversationId,
    String userId, {
    int ttlSeconds = 3,
  }) async {
    if (conversationId.isEmpty || userId.isEmpty) return;
    await executeCommand([
      'SET',
      'typing:$conversationId:$userId',
      '1',
      'EX',
      ttlSeconds
    ]);
  }

  /// Kiểm tra user có đang gõ trong cuộc trò chuyện hay không
  Future<bool> isUserTyping(String conversationId, String userId) async {
    if (conversationId.isEmpty || userId.isEmpty) return false;
    final res = await executeCommand(['EXISTS', 'typing:$conversationId:$userId']);
    return res != null && (res == 1 || res == '1');
  }

  // ── 4. Hot Messages Cache (50 tin nhắn mới nhất) ───────────────────────

  /// Đẩy tin nhắn mới vào Cache (Giữ tối đa 50 tin)
  Future<void> cacheRecentMessage(
    String conversationId,
    Map<String, dynamic> messageJson,
  ) async {
    if (conversationId.isEmpty) return;
    final key = 'conv:messages:$conversationId';
    final jsonStr = jsonEncode(messageJson);

    await executePipeline([
      ['LPUSH', key, jsonStr],
      ['LTRIM', key, 0, 49],
    ]);
  }

  /// Đặt toàn bộ 50 tin nhắn vào Cache (Write-through)
  Future<void> cacheMessagesList(
    String conversationId,
    List<Map<String, dynamic>> messagesList,
  ) async {
    if (conversationId.isEmpty || messagesList.isEmpty) return;
    final key = 'conv:messages:$conversationId';

    final commands = <List<dynamic>>[
      ['DEL', key],
    ];

    // Đẩy từ tin cũ nhất đến tin mới nhất
    for (final msg in messagesList.reversed) {
      commands.add(['LPUSH', key, jsonEncode(msg)]);
    }
    commands.add(['LTRIM', key, 0, 49]);

    await executePipeline(commands);
  }

  /// Lấy 50 tin nhắn gần nhất từ Upstash Redis
  Future<List<Map<String, dynamic>>> getCachedRecentMessages(
    String conversationId,
  ) async {
    if (conversationId.isEmpty) return [];

    final key = 'conv:messages:$conversationId';
    final res = await executeCommand(['LRANGE', key, 0, 49]);

    if (res is List && res.isNotEmpty) {
      final list = <Map<String, dynamic>>[];
      for (final item in res) {
        if (item is String) {
          try {
            final decoded = jsonDecode(item);
            if (decoded is Map<String, dynamic>) {
              list.add(decoded);
            }
          } catch (_) {}
        }
      }
      return list;
    }
    return [];
  }

  /// Xóa cache tin nhắn của cuộc trò chuyện
  Future<void> invalidateMessagesCache(String conversationId) async {
    if (conversationId.isEmpty) return;
    await executeCommand(['DEL', 'conv:messages:$conversationId']);
  }

  // ── 5. Session Management & Token Revocation ─────────────────────────────

  /// Vô hiệu hóa session ID
  Future<void> revokeSession(String sessionId, {int ttlSeconds = 86400}) async {
    if (sessionId.isEmpty) return;
    await executeCommand(['SET', 'session:revoked:$sessionId', '1', 'EX', ttlSeconds]);
  }

  /// Kiểm tra session ID có bị revoked hay chưa
  Future<bool> isSessionRevoked(String sessionId) async {
    if (sessionId.isEmpty) return false;
    final res = await executeCommand(['EXISTS', 'session:revoked:$sessionId']);
    return res != null && (res == 1 || res == '1');
  }
}
