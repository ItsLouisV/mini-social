import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupabaseService {
  final SupabaseClient client;

  SupabaseService(this.client);

  /// Trả về ID của người dùng hiện tại
  String? get currentUserId => client.auth.currentUser?.id;

  /// Helper để tải tệp lên Storage và lấy URL công khai
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required XFile file,
    bool upsert = true,
  }) async {
    final bytes = await file.readAsBytes();
    
    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
            upsert: upsert,
          ),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }
}

/// Provider cho SupabaseService
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = Supabase.instance.client;
  return SupabaseService(client);
});
