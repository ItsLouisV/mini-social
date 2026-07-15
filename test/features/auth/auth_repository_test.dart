import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:mini_social/features/auth/data/auth_repository.dart';

class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final String fn;
  final Map<String, dynamic>? params;

  FakePostgrestFilterBuilder(this.fn, this.params);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    if (fn == 'get_active_sessions') {
      final sessions = [
        {
          'id': 'session_1',
          'created_at': '2026-07-15T00:00:00.000Z',
          'updated_at': '2026-07-15T01:00:00.000Z',
          'user_agent': 'Chrome on Windows',
          'ip': '127.0.0.1'
        }
      ];
      return Future.value(onValue(sessions as T));
    }
    return Future.value(onValue(null as T));
  }
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  OAuthProvider? lastProvider;
  String? lastRedirectTo;

  @override
  Future<OAuthResponse> getOAuthSignInUrl({
    required OAuthProvider provider,
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    lastProvider = provider;
    lastRedirectTo = redirectTo;
    return OAuthResponse(url: 'https://fake-supabase-oauth-url.com', provider: provider);
  }

  @override
  Future<bool> signInWithOAuth(
    OAuthProvider provider, {
    String? redirectTo,
    String? scopes,
    Map<String, String>? queryParams,
  }) async {
    lastProvider = provider;
    lastRedirectTo = redirectTo;
    return true;
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeGoTrueClient _auth = FakeGoTrueClient();
  final Map<String, Map<String, dynamic>?> rpcCalls = {};

  @override
  GoTrueClient get auth => _auth;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    rpcCalls[fn] = params;
    return FakePostgrestFilterBuilder<T>(fn, params);
  }
}

class FakeUrlLauncher extends UrlLauncherPlatform {
  String? launchedUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepository Unit Tests', () {
    late FakeSupabaseClient fakeClient;
    late AuthRepository authRepository;
    late FakeUrlLauncher fakeUrlLauncher;

    setUp(() {
      fakeClient = FakeSupabaseClient();
      authRepository = AuthRepository(fakeClient);
      fakeUrlLauncher = FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeUrlLauncher;
    });

    test('signInWithGoogle invokes signInWithOAuth with Google provider', () async {
      final result = await authRepository.signInWithGoogle();

      expect(result, isTrue);
      expect(fakeClient._auth.lastProvider, equals(OAuthProvider.google));
      expect(fakeClient._auth.lastRedirectTo, equals('minisocial://login-callback'));
    });

    test('signInWithApple invokes signInWithOAuth with Apple provider', () async {
      final result = await authRepository.signInWithApple();

      expect(result, isTrue);
      expect(fakeClient._auth.lastProvider, equals(OAuthProvider.apple));
      expect(fakeClient._auth.lastRedirectTo, equals('minisocial://login-callback'));
    });

    test('getActiveSessions calls rpc and returns session list', () async {
      final sessions = await authRepository.getActiveSessions();

      expect(sessions, isNotEmpty);
      expect(sessions.length, equals(1));
      expect(sessions.first['id'], equals('session_1'));
      expect(sessions.first['user_agent'], equals('Chrome on Windows'));
      expect(fakeClient.rpcCalls.containsKey('get_active_sessions'), isTrue);
    });

    test('revokeSession calls rpc with correct session_id parameter', () async {
      await authRepository.revokeSession('test_session_id');

      expect(fakeClient.rpcCalls.containsKey('revoke_session'), isTrue);
      expect(fakeClient.rpcCalls['revoke_session']?['session_id'], equals('test_session_id'));
    });
  });
}
