import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/image_compressor.dart';

class SupabaseService {
  final SupabaseClient client;
  final Ref ref;

  Completer<bool>? _refreshCompleter;

  SupabaseService(this.client, this.ref);

  /// Trả về ID của người dùng hiện tại
  String? get currentUserId => client.auth.currentUser?.id;

  /// Xử lý lỗi Token hết hạn / Invalid JWT.
  /// Thử refresh session trước (có cơ chế mutex / deduplication chống race condition).
  /// Nếu thất bại, đăng xuất và hiển thị thông báo hết hạn.
  Future<bool> handleAuthError(dynamic error) async {
    final errorStr = error.toString();
    final isExplicitTokenError = (error is AuthException && (
          error.message.contains('Invalid Refresh Token') ||
          error.message.contains('refresh_token_not_found') ||
          error.statusCode == '401'
        )) ||
        errorStr.contains('InvalidJWTToken') ||
        errorStr.contains('JWT expired') ||
        errorStr.contains('jwt_expired');

    if (!isExplicitTokenError) return false;

    // Nếu đã có một tác vụ refresh đang chạy đồng thời, chờ nó hoàn tất
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    // Kiểm tra nếu session đã được làm mới ở nơi khác và còn hạn
    final currentSession = client.auth.currentSession;
    if (currentSession != null && !currentSession.isExpired) {
      try {
        client.realtime.setAuth(currentSession.accessToken);
      } catch (_) {}
      return true;
    }

    _refreshCompleter = Completer<bool>();

    try {
      print('Detected expired JWT token. Attempting to refresh session...');
      final response = await client.auth.refreshSession();
      if (response.session != null) {
        print('Successfully refreshed session.');
        try {
          client.realtime.setAuth(response.session!.accessToken);
        } catch (_) {}
        _refreshCompleter!.complete(true);
        _refreshCompleter = null;
        return true;
      }
    } catch (e) {
      print('Error refreshing session: $e');
      final sessionAfterErr = client.auth.currentSession;
      if (sessionAfterErr != null && !sessionAfterErr.isExpired) {
        try {
          client.realtime.setAuth(sessionAfterErr.accessToken);
        } catch (_) {}
        _refreshCompleter!.complete(true);
        _refreshCompleter = null;
        return true;
      }
    }

    _refreshCompleter!.complete(false);
    _refreshCompleter = null;
    return false;
  }

  /// Helper để tải tệp lên Storage và lấy URL công khai
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required XFile file,
    bool upsert = true,
    bool compressImage = true,
    String cacheControl = '31536000', // 1 năm (long-term CDN caching)
  }) async {
    final ext = file.name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext);

    Uint8List bytes;
    if (isImage && compressImage) {
      bytes = await ImageCompressor.compressXFile(file);
    } else {
      bytes = await file.readAsBytes();
    }

    final contentType = switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'm4a' => 'audio/m4a',
      'mp3' => 'audio/mpeg',
      _ => 'image/jpeg',
    };

    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: upsert,
            cacheControl: cacheControl,
          ),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }
}

/// Provider cho SupabaseService
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = Supabase.instance.client;
  return SupabaseService(client, ref);
});
