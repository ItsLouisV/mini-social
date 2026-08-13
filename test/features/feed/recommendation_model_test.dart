import 'package:flutter_test/flutter_test.dart';
import 'package:viora/features/feed/domain/post_model.dart';

void main() {
  test('PostModel preserves recommendation metadata from the server', () {
    final post = PostModel.fromJson({
      'id': 'post-1',
      'user_id': 'user-1',
      'caption': 'A recent post',
      'created_at': '2026-08-13T00:00:00.000Z',
      'recommendation_score': 42.5,
      'recommendation_source': 'discovery',
      'recommendation_reasons': ['matching_interest', 'recent'],
    });

    expect(post.recommendationScore, 42.5);
    expect(post.recommendationSource, 'discovery');
    expect(post.recommendationReasons, ['matching_interest', 'recent']);
    expect(post.toJson()['recommendation_source'], 'discovery');
  });
}
