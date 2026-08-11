import 'package:flutter_test/flutter_test.dart';
import 'package:viora/features/feed/domain/post_model.dart';
import 'package:viora/features/location/domain/place_model.dart';

void main() {
  test('post location snapshot round-trips through JSON', () {
    final post = PostModel(
      id: 'post-1',
      userId: 'user-1',
      caption: 'Hello',
      createdAt: DateTime.utc(2026, 8, 12),
      location: const PlaceModel(
        providerPlaceId: 'osm:node:1',
        name: 'Landmark 81',
        address: 'Bình Thạnh, Hồ Chí Minh',
        latitude: 10.7949,
        longitude: 106.7219,
      ),
    );

    final json = post.toJson();
    final parsed = PostModel.fromJson(json);

    expect(parsed.location?.name, 'Landmark 81');
    expect(parsed.location?.latitude, 10.7949);
    expect(parsed.location?.longitude, 106.7219);
  });

  test('post without complete coordinates has no location', () {
    final json = <String, dynamic>{
      'id': 'post-1',
      'user_id': 'user-1',
      'caption': null,
      'created_at': '2026-08-12T00:00:00.000Z',
      'location_name': 'Incomplete place',
    };

    expect(PostModel.fromJson(json).location, isNull);
  });
}
