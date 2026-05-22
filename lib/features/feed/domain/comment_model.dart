import '../../profile/domain/profile_model.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String? parentId;
  final String content;
  final int likesCount;
  final bool isLiked;
  final DateTime createdAt;
  final ProfileModel? author;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    required this.content,
    this.likesCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.author,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json, {bool isLiked = false}) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      userId: json['user_id'] as String,
      parentId: json['parent_id'] as String?,
      content: json['content'] as String,
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: isLiked,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: json['profiles'] != null
          ? ProfileModel.fromJson(
              Map<String, dynamic>.from(json['profiles'] as Map))
          : null,
    );
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? parentId,
    String? content,
    int? likesCount,
    bool? isLiked,
    DateTime? createdAt,
    ProfileModel? author,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      parentId: parentId ?? this.parentId,
      content: content ?? this.content,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      author: author ?? this.author,
    );
  }
}
