import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/place_model.dart';

class PlacesRepository {
  final SupabaseClient _client;
  PlacesRepository(this._client);

  Future<List<PlaceModel>> nearby(double latitude, double longitude) =>
      _invoke('nearby', latitude: latitude, longitude: longitude);

  Future<List<PlaceModel>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) =>
      _invoke(
        'search',
        query: query,
        latitude: latitude,
        longitude: longitude,
      );

  Future<List<PlaceModel>> reverse(double latitude, double longitude) =>
      _invoke('reverse', latitude: latitude, longitude: longitude);

  Future<List<PlaceModel>> _invoke(
    String action, {
    String? query,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.functions.invoke(
      'places-service',
      body: {
        'action': action,
        if (query != null) 'query': query,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Không thể tải địa điểm');
    }
    final data = response.data as Map<String, dynamic>;
    return (data['places'] as List? ?? const [])
        .map((item) => PlaceModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((place) => place.name.isNotEmpty)
        .toList();
  }
}
