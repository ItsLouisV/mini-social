# 📁 Folder Structure — Flutter Project

```
mini_social/
├── .env                          # SUPABASE_URL, SUPABASE_ANON_KEY
├── .env.example
├── pubspec.yaml
│
└── lib/
    ├── main.dart                 # Entry point, ProviderScope, runApp
    │
    ├── core/
    │   ├── constants/
    │   │   ├── app_colors.dart
    │   │   ├── app_text_styles.dart
    │   │   └── supabase_constants.dart   # bucket names, table names
    │   │
    │   ├── extensions/
    │   │   ├── date_extension.dart       # timeago helper
    │   │   └── string_extension.dart
    │   │
    │   ├── theme/
    │   │   ├── app_theme.dart            # light theme
    │   │   └── dark_theme.dart
    │   │
    │   ├── router/
    │   │   └── app_router.dart           # GoRouter config
    │   │
    │   └── utils/
    │       ├── image_utils.dart
    │       └── validators.dart
    │
    ├── shared/
    │   ├── widgets/
    │   │   ├── app_avatar.dart           # CircleAvatar có cache
    │   │   ├── app_button.dart
    │   │   ├── app_text_field.dart
    │   │   ├── loading_indicator.dart
    │   │   └── error_widget.dart
    │   │
    │   └── providers/
    │       └── supabase_provider.dart    # ref.watch(supabaseClientProvider)
    │
    ├── features/
    │   │
    │   ├── auth/
    │   │   ├── data/
    │   │   │   └── auth_repository.dart
    │   │   ├── presentation/
    │   │   │   ├── screens/
    │   │   │   │   ├── login_screen.dart
    │   │   │   │   ├── register_screen.dart
    │   │   │   │   └── forgot_password_screen.dart
    │   │   │   └── widgets/
    │   │   │       └── auth_form.dart
    │   │   └── providers/
    │   │       └── auth_provider.dart    # authStateProvider (StreamProvider)
    │   │
    │   ├── profile/
    │   │   ├── data/
    │   │   │   └── profile_repository.dart
    │   │   ├── domain/
    │   │   │   └── profile_model.dart
    │   │   ├── presentation/
    │   │   │   ├── screens/
    │   │   │   │   ├── profile_screen.dart
    │   │   │   │   └── edit_profile_screen.dart
    │   │   │   └── widgets/
    │   │   │       ├── profile_header.dart
    │   │   │       └── profile_posts_grid.dart
    │   │   └── providers/
    │   │       └── profile_provider.dart
    │   │
    │   ├── feed/
    │   │   ├── data/
    │   │   │   └── post_repository.dart
    │   │   ├── domain/
    │   │   │   ├── post_model.dart
    │   │   │   └── comment_model.dart
    │   │   ├── presentation/
    │   │   │   ├── screens/
    │   │   │   │   ├── feed_screen.dart         # AppBar có icon 🔍
    │   │   │   │   ├── create_post_screen.dart
    │   │   │   │   └── post_detail_screen.dart
    │   │   │   └── widgets/
    │   │   │       ├── feed_app_bar.dart        # AppBar với logo + icon search
    │   │   │       ├── post_card.dart
    │   │   │       ├── post_actions.dart        # Like, Comment, Share buttons
    │   │   │       ├── comment_tile.dart
    │   │   │       └── image_carousel.dart
    │   │   └── providers/
    │   │       ├── feed_provider.dart
    │   │       └── post_provider.dart
    │   │
    │   ├── search/
    │   │   ├── data/
    │   │   │   └── search_repository.dart      # ilike query trên profiles
    │   │   ├── presentation/
    │   │   │   ├── screens/
    │   │   │   │   └── search_screen.dart      # push từ FeedScreen, không có bottom nav
    │   │   │   └── widgets/
    │   │   │       └── search_user_tile.dart   # avatar + tên + username + follow button
    │   │   └── providers/
    │   │       └── search_provider.dart        # debounce 400ms
    │   │
    │   ├── social/
    │   │   ├── data/
    │   │   │   └── social_repository.dart
    │   │   ├── presentation/
    │   │   │   ├── screens/
    │   │   │   │   └── notification_screen.dart
    │   │   │   └── widgets/
    │   │   │       ├── follow_button.dart
    │   │   │       └── notification_tile.dart
    │   │   └── providers/
    │   │       ├── follow_provider.dart
    │   │       └── notification_provider.dart
    │   │
    │   └── chat/
    │       ├── data/
    │       │   └── chat_repository.dart
    │       ├── domain/
    │       │   ├── conversation_model.dart
    │       │   └── message_model.dart
    │       ├── presentation/
    │       │   ├── screens/
    │       │   │   ├── conversations_screen.dart
    │       │   │   └── chat_screen.dart
    │       │   └── widgets/
    │       │       ├── message_bubble.dart
    │       │       ├── chat_input.dart
    │       │       └── conversation_tile.dart
    │       └── providers/
    │           ├── chat_provider.dart
    │           └── realtime_chat_provider.dart   # StreamProvider Supabase Realtime
    │
    └── app.dart                  # MaterialApp.router + theme switching
```

---

## Quy ước đặt tên

| Loại | Convention | Ví dụ |
|---|---|---|
| File | snake_case | `post_card.dart` |
| Class | PascalCase | `PostCard` |
| Provider | camelCase + Provider | `feedProvider` |
| Repository | PascalCase + Repository | `PostRepository` |
| Model | PascalCase + Model | `PostModel` |
| Screen | PascalCase + Screen | `FeedScreen` |

---

## Routing (GoRouter)

```
/                       → Redirect (auth guard)
/login                  → LoginScreen
/register               → RegisterScreen
/forgot-password        → ForgotPasswordScreen

── MainShell (ShellRoute — có Bottom Nav) ──────────────────
/feed                   → FeedScreen            (Tab 1 🏠)
/chat                   → ConversationsScreen   (Tab 2 💬)
/create                 → CreatePostScreen      (Tab 3 ➕)
/notifications          → NotificationScreen    (Tab 4 🔔)
/profile/me             → ProfileScreen (mình)  (Tab 5 👤)

── Sub-routes (push, KHÔNG có Bottom Nav) ──────────────────
/search                 → SearchScreen          (từ icon 🔍 trên FeedScreen AppBar)
/feed/post/:id          → PostDetailScreen
/chat/:conversationId   → ChatScreen
/profile/:userId        → ProfileScreen (người khác)
/profile/edit           → EditProfileScreen
/settings               → SettingsScreen
```

---

## State Management Pattern (Riverpod)

```dart
// Repository: thuần Dart, không biết Riverpod
class PostRepository {
  final SupabaseClient _client;
  PostRepository(this._client);
  
  Future<List<PostModel>> getFeedPosts({int page = 0}) async { ... }
}

// Provider
@riverpod
PostRepository postRepository(PostRepositoryRef ref) {
  return PostRepository(ref.watch(supabaseClientProvider));
}

// Feed (phân trang)
@riverpod
Future<List<PostModel>> feedPosts(FeedPostsRef ref, {int page = 0}) async {
  return ref.watch(postRepositoryProvider).getFeedPosts(page: page);
}
```
