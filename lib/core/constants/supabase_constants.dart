class SupabaseConstants {
  SupabaseConstants._();

  // Table names
  static const String profilesTable = 'profiles';
  static const String postsTable = 'posts';
  static const String likesTable = 'likes';
  static const String commentsTable = 'comments';
  static const String followsTable = 'follows';
  static const String notificationsTable = 'notifications';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  static const String postMediaTable = 'post_media';
  static const String storiesTable = 'stories';
  static const String conversationSettingsTable = 'conversation_settings';

  // Storage bucket names
  static const String avatarsBucket = 'avatars';
  static const String coversBucket = 'covers';
  static const String postsBucket = 'posts';
  static const String messagesBucket = 'messages';
  static const String wallpapersBucket = 'wallpapers';

  // Realtime channels
  static const String messagesChannel = 'messages';
  static const String notificationsChannel = 'notifications';
}
