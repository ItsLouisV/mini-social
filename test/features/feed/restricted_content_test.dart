import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viora/features/feed/domain/comment_model.dart';
import 'package:viora/shared/widgets/restricted_content_reveal.dart';

void main() {
  test('CommentModel recognizes only shadow-limited content as revealable', () {
    final comment = CommentModel.fromJson({
      'id': 'comment-1',
      'post_id': 'post-1',
      'user_id': 'user-1',
      'content': 'Restricted content',
      'created_at': '2026-08-13T00:00:00.000Z',
      'moderation_status': 'shadow_limited',
    });

    expect(comment.isRestricted, isTrue);
    expect(comment.moderationStatus, 'shadow_limited');
  });

  testWidgets('restricted content notice reveals content on demand',
      (tester) async {
    var revealed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RestrictedContentReveal(
          actionLabel: 'Xem bình luận đã bị ẩn',
          onReveal: () => revealed = true,
        ),
      ),
    );

    expect(find.text(restrictedContentNotice), findsOneWidget);
    expect(find.byIcon(Icons.remove_red_eye_outlined), findsNothing);
    await tester.tap(find.text('Xem bình luận đã bị ẩn'));
    expect(revealed, isTrue);
  });
}
