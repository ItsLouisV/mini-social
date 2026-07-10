import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';

class SupabaseService {
  final SupabaseClient client;
  final Ref ref;

  SupabaseService(this.client, this.ref);

  /// Trả về ID của người dùng hiện tại
  String? get currentUserId => client.auth.currentUser?.id;

  /// Xử lý lỗi Token hết hạn / Invalid JWT.
  /// Thử refresh session trước. Nếu thất bại, đăng xuất và hiển thị thông báo hết hạn.
  Future<void> handleAuthError(dynamic error) async {
    final errorStr = error.toString();
    if (errorStr.contains('InvalidJWTToken') || errorStr.contains('Token has expired')) {
      print('Detected expired JWT token. Attempting to refresh session...');
      try {
        final response = await client.auth.refreshSession();
        if (response.session != null) {
          print('Successfully refreshed session.');
          return;
        }
      } catch (e) {
        print('Error refreshing session: $e');
      }

      print('Session refresh failed. Marking session as expired and signing out.');
      // Đánh dấu hết hạn để hiển thị thông báo ở UI
      ref.read(sessionExpiredProvider.notifier).state = true;
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
  }

  /// Helper để tải tệp lên Storage và lấy URL công khai
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required XFile file,
    bool upsert = true,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: upsert,
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
