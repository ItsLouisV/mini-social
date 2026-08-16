import '../../music/domain/music_track_model.dart';
import '../../profile/domain/profile_model.dart';

class StoryModel {
  final String id;
  final String userId;
  final String? mediaUrl;
  final String? caption;
  final MusicTrackModel? musicTrack;
  final String backgroundColor;
  final DateTime createdAt;
  final DateTime expiresAt;
  final ProfileModel? author;

  const StoryModel({
    required this.id,
    required this.userId,
    this.mediaUrl,
    this.caption,
    this.musicTrack,
    this.backgroundColor = '#1C1C1E',
    required this.createdAt,
    required this.expiresAt,
    this.author,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mediaUrl: json['media_url'] as String?,
      caption: json['caption'] as String?,
      musicTrack: json['music_track'] != null
          ? MusicTrackModel.fromJson(
              Map<String, dynamic>.from(json['music_track'] as Map))
          : null,
      backgroundColor: json['background_color'] as String? ?? '#1C1C1E',
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      author: json['profiles'] != null
          ? ProfileModel.fromJson(
              Map<String, dynamic>.from(json['profiles'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'media_url': mediaUrl,
        'caption': caption,
        'music_track': musicTrack?.toJson(),
        'background_color': backgroundColor,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        if (author != null) 'profiles': author!.toJson(),
      };
}
