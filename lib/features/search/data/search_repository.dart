import 'package:flutter/foundation.dart' show debugPrint;
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/domain/profile_model.dart';
import '../../feed/domain/post_model.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/isar_service.dart';
import '../../../core/database/collections/isar_search_history.dart';

class SearchRepository {
  final SupabaseClient _client;
  final IsarService? _isarService;

  SearchRepository(this._client, [this._isarService]);

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

  /// Tìm kiếm bài viết theo caption (Ưu tiên AI Hybrid Search, Fallback ILIKE)
  Future<List<PostModel>> searchPosts(String query, {dynamic aiRepository}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Ưu tiên AI Hybrid Search (Semantic + Full-Text Search RRF)
    if (aiRepository != null) {
      try {
        final aiResults = await aiRepository.hybridSearchPosts(cleanQuery);
        if (aiResults is List<PostModel> && aiResults.isNotEmpty) {
          return aiResults;
        }
      } catch (_) {}
    }

    // 2. Fallback sang ILIKE truyền thống
    try {
      final data = await _client
          .from(SupabaseConstants.postsTable)
          .select('*, profiles(*), post_media(*)')
          .ilike('caption', '%$cleanQuery%')
          .filter('deleted_at', 'is', null)
          .eq('moderation_status', 'published')
          .order('created_at', ascending: false)
          .limit(30);

      final list = (data as List).map((e) => PostModel.fromJson(e)).where((post) {
        final status = post.moderationStatus ?? 'published';
        if (post.userId != _currentUserId) {
          if (status != 'published' || status == 'hidden' || status == 'removed') {
            return false;
          }
        }
        return true;
      }).toList();
      return list;
    } catch (e) {
      // Fallback nếu cột deleted_at chưa được tạo trên db môi trường sản xuất
      final data = await _client
          .from(SupabaseConstants.postsTable)
          .select('*, profiles(*), post_media(*)')
          .ilike('caption', '%$cleanQuery%')
          .eq('moderation_status', 'published')
          .order('created_at', ascending: false)
          .limit(30);

      final list = (data as List).map((e) => PostModel.fromJson(e)).where((post) {
        final status = post.moderationStatus ?? 'published';
        if (post.userId != _currentUserId) {
          if (status != 'published' || status == 'hidden' || status == 'removed') {
            return false;
          }
        }
        return true;
      }).toList();
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

  /// Lưu lịch sử tìm kiếm vào Isar / Hive DB
  Future<void> saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    if (_isarService?.isar != null) {
      final cleanQuery = query.trim();
      final item = IsarSearchHistory(
        id: cleanQuery.toLowerCase(),
        query: cleanQuery,
        timestamp: DateTime.now().toUtc(),
      );
      await _isarService!.isar!.writeTxn(() async {
        await _isarService!.isar!.isarSearchHistorys.put(item);
      });
    } else if (_isarService?.webService != null) {
      await _isarService!.webService!.saveSearchQuery(query);
    }
  }

  /// Đọc lịch sử tìm kiếm từ Isar / Hive DB
  Future<List<String>> getSearchHistory({int limit = 10}) async {
    if (_isarService?.isar != null) {
      final items = await _isarService!.isar!.isarSearchHistorys
          .where()
          .sortByTimestampDesc()
          .limit(limit)
          .findAll();
      return items.map((e) => e.query).toList();
    } else if (_isarService?.webService != null) {
      return _isarService!.webService!.getSearchHistory(limit: limit);
    }
    return [];
  }

  /// Xóa sạch lịch sử tìm kiếm Isar / Hive DB
  Future<void> clearSearchHistory() async {
    if (_isarService?.isar != null) {
      await _isarService!.isar!.writeTxn(() async {
        await _isarService!.isar!.isarSearchHistorys.clear();
      });
    } else if (_isarService?.webService != null) {
      await _isarService!.webService!.clearSearchHistory();
    }
  }
}
