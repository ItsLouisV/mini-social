import '../../profile/domain/profile_model.dart';

class PostMedia {
  final String id;
  final String postId;
  final String url;
  final String? path;
  final String type; // 'image' | 'video'
  final int orderIndex;
  final DateTime createdAt;
  final int? width;
  final int? height;
  final double? aspectRatio;
  final String? thumbnailUrl;

  const PostMedia({
    required this.id,
    required this.postId,
    required this.url,
    this.path,
    this.type = 'image',
    this.orderIndex = 0,
    required this.createdAt,
    this.width,
    this.height,
    this.aspectRatio,
    this.thumbnailUrl,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    final w = (json['width'] as num?)?.toInt();
    final h = (json['height'] as num?)?.toInt();
    final ar = (json['aspect_ratio'] ?? json['aspectRatio'] as num?)?.toDouble() ??
        (w != null && h != null && h > 0 ? w / h : null);

    return PostMedia(
      id: (json['id'] ?? '') as String,
      postId: (json['post_id'] ?? json['postId'] ?? '') as String,
      url: (json['url'] ?? '') as String,
      path: json['path'] as String?,
      type: (json['type'] ?? 'image') as String,
      orderIndex: (json['order_index'] ?? json['orderIndex'] ?? 0) as int,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
      width: w,
      height: h,
      aspectRatio: ar,
      thumbnailUrl: json['thumbnail_url'] as String? ?? json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'url': url,
        'path': path,
        'type': type,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
        'width': width,
        'height': height,
        'aspect_ratio': aspectRatio,
        'thumbnail_url': thumbnailUrl,
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
  final bool isLiked;
  final String privacy;
  final String layoutType;

  const PostModel({
    required this.id,
    required this.userId,
    this.caption,
    this.media = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.author,
    this.isLiked = false,
    this.privacy = 'public',
    this.layoutType = 'grid',
  });

  factory PostModel.fromJson(Map<String, dynamic> json, {bool isLiked = false}) {
    String? rawCaption = json['caption'] as String?;
    String extractedLayout = json['layout_type'] as String? ?? 'grid';

    if (rawCaption != null && rawCaption.contains('[layout:')) {
      final regExp = RegExp(r'\[layout:(dashboard|columns|panel-left|panel-top|grid|vertical|hero|horizontal)\]');
      final match = regExp.firstMatch(rawCaption);
      if (match != null) {
        extractedLayout = match.group(1) ?? extractedLayout;
        rawCaption = rawCaption.replaceAll(regExp, '').trim();
        if (rawCaption.isEmpty) rawCaption = null;
      }
    }

    return PostModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      caption: rawCaption,
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
      isLiked: isLiked,
      privacy: json['privacy'] as String? ?? 'public',
      layoutType: extractedLayout,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'caption': caption,
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'created_at': createdAt.toIso8601String(),
        'privacy': privacy,
        'layout_type': layoutType,
      };

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    String? layoutType,
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
      isLiked: isLiked ?? this.isLiked,
      privacy: privacy,
      layoutType: layoutType ?? this.layoutType,
    );
  }
}
