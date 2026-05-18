import '../../profile/domain/profile_model.dart';

class PostMedia {
  final String id;
  final String postId;
  final String url;
  final String type; // 'image' | 'video'
  final int orderIndex;
  final DateTime createdAt;

  const PostMedia({
    required this.id,
    required this.postId,
    required this.url,
    this.type = 'image',
    this.orderIndex = 0,
    required this.createdAt,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      url: json['url'] as String,
      type: json['type'] as String? ?? 'image',
      orderIndex: json['order_index'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'url': url,
        'type': type,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
      };
}

class PostModel {
  final String id;
  final String userId;
  final String? caption;
  final List<PostMedia> media;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final ProfileModel? author;

  const PostModel({
    required this.id,
    required this.userId,
    this.caption,
    this.media = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.author,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      caption: json['caption'] as String?,
      media: (json['post_media'] as List?)
              ?.map((e) => PostMedia.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: json['profiles'] != null
          ? ProfileModel.fromJson(
              Map<String, dynamic>.from(json['profiles'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'caption': caption,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'created_at': createdAt.toIso8601String(),
      };

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      caption: caption,
      media: media,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt,
      author: author,
    );
  }
}
