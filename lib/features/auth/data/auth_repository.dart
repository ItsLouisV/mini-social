import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Kích hoạt luồng đăng nhập bằng Google (Web-based OAuth)
  Future<bool> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'minisocial://login-callback',
    );
  }

  /// Kích hoạt luồng đăng nhập bằng Apple (Web-based OAuth)
  Future<bool> signInWithApple() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kIsWeb ? null : 'minisocial://login-callback',
    );
  }

  /// Lấy danh sách các phiên thiết bị đăng nhập đang hoạt động
  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    final response = await _client.rpc('get_active_sessions');
    if (response == null) return [];
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Thu hồi một phiên làm việc cụ thể để đăng xuất từ xa
  Future<void> revokeSession(String sessionId) async {
    await _client.rpc('revoke_session', params: {'session_id': sessionId});
  }
}
