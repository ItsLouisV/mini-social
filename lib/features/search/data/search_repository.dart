import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/domain/profile_model.dart';
import '../../../core/constants/supabase_constants.dart';

class SearchRepository {
  final SupabaseClient _client;

  SearchRepository(this._client);

  Future<List<ProfileModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final data = await _client
        .from(SupabaseConstants.profilesTable)
        .select()
        .or('username.ilike.%$query%,full_name.ilike.%$query%')
        .limit(20);

    return (data as List).map((e) => ProfileModel.fromJson(e)).toList();
  }
}
