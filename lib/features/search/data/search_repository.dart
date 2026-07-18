import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/domain/profile_model.dart';
import '../../feed/domain/post_model.dart';
import '../../../core/constants/supabase_constants.dart';

class SearchRepository {
  final SupabaseClient _client;

  SearchRepository(this._client);

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Tìm kiếm người dùng theo username hoặc full_name
  Future<List<ProfileModel>> searchUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final data = await _client
        .from(SupabaseConstants.profilesTable)
        .select()
        .or('username.ilike.%$cleanQuery%,full_name.ilike.%$cleanQuery%')
        .limit(30);

    final list = (data as List).map((e) => ProfileModel.fromJson(e)).toList();
    // Loại trừ tài khoản chính mình nếu có
    if (_currentUserId != null) {
      return list.where((u) => u.id != _currentUserId).toList();
    }
    return list;
  }

  /// Tìm kiếm bài viết theo caption
  Future<List<PostModel>> searchPosts(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final data = await _client
          .from(SupabaseConstants.postsTable)
          .select('*, profiles(*), post_media(*)')
          .ilike('caption', '%$cleanQuery%')
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false)
          .limit(30);

      final list = (data as List).map((e) => PostModel.fromJson(e)).toList();
      return list;
    } catch (e) {
      // Fallback nếu cột deleted_at chưa được tạo trên db môi trường sản xuất
      final data = await _client
          .from(SupabaseConstants.postsTable)
          .select('*, profiles(*), post_media(*)')
          .ilike('caption', '%$cleanQuery%')
          .order('created_at', ascending: false)
          .limit(30);

      final list = (data as List).map((e) => PostModel.fromJson(e)).toList();
      return list;
    }
  }

  /// Lấy danh sách gợi ý người dùng (khi chưa tìm kiếm)
  Future<List<ProfileModel>> getSuggestedUsers({int limit = 10}) async {
    final data = await _client
        .from(SupabaseConstants.profilesTable)
        .select()
        .limit(limit * 2);

    final list = (data as List).map((e) => ProfileModel.fromJson(e)).toList();
    if (_currentUserId != null) {
      return list.where((u) => u.id != _currentUserId).take(limit).toList();
    }
    return list.take(limit).toList();
  }
}
