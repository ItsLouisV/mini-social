import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mini_social/features/profile/data/profile_repository.dart';
import 'package:mini_social/core/services/supabase_service.dart';

// Giả lập PostgrestFilterBuilder hỗ trợ phương thức so sánh eq() và then()
class FakePostgrestFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final Map<String, dynamic> lastQuery;
  
  FakePostgrestFilterBuilder(this.lastQuery);

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    lastQuery['eq_column'] = column;
    lastQuery['eq_value'] = value;
    return this;
  }

  @override
  Future<U> then<U>(FutureOr<U> Function(T value) onValue, {Function? onError}) {
    return Future.value(onValue(null as T));
  }
}

// Giả lập SupabaseQueryBuilder đúng chữ ký (không có generic trên phương thức update/insert/delete)
class FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final Map<String, dynamic> lastQuery;

  FakeSupabaseQueryBuilder(this.lastQuery);

  @override
  PostgrestFilterBuilder update(Map values) {
    lastQuery['action'] = 'update';
    lastQuery['values'] = values;
    return FakePostgrestFilterBuilder(lastQuery);
  }

  @override
  PostgrestFilterBuilder insert(dynamic values, {bool? defaultToNull}) {
    lastQuery['action'] = 'insert';
    lastQuery['values'] = values;
    return FakePostgrestFilterBuilder(lastQuery);
  }

  @override
  PostgrestFilterBuilder delete() {
    lastQuery['action'] = 'delete';
    return FakePostgrestFilterBuilder(lastQuery);
  }
}

// Giả lập SupabaseClient trả về SupabaseQueryBuilder
class FakeSupabaseClient extends Fake implements SupabaseClient {
  final Map<String, dynamic> lastQuery = {};

  @override
  SupabaseQueryBuilder from(String table) {
    lastQuery['table'] = table;
    lastQuery['action'] = null;
    lastQuery['values'] = null;
    return FakeSupabaseQueryBuilder(lastQuery);
  }
}

// Giả lập SupabaseService cung cấp Client giả lập và User ID giả lập
class FakeSupabaseService extends Fake implements SupabaseService {
  final FakeSupabaseClient fakeClient = FakeSupabaseClient();

  @override
  SupabaseClient get client => fakeClient;

  @override
  String? get currentUserId => 'user_123';
}

void main() {
  group('ProfileRepository Unit Tests', () {
    late FakeSupabaseService fakeService;
    late ProfileRepository profileRepository;

    setUp(() {
      fakeService = FakeSupabaseService();
      profileRepository = ProfileRepository(fakeService);
    });

    test('updateProfile updates interests and private profile settings', () async {
      await profileRepository.updateProfile(
        userId: 'user_123',
        fullName: 'Louis V',
        interests: ['Gaming', 'Coding'],
        isPrivateProfile: true,
      );

      final query = fakeService.fakeClient.lastQuery;
      expect(query['table'], equals('profiles'));
      expect(query['action'], equals('update'));
      expect(query['values']['full_name'], equals('Louis V'));
      expect(query['values']['interests'], equals(['Gaming', 'Coding']));
      expect(query['values']['is_private_profile'], isTrue);
      expect(query['eq_column'], equals('id'));
      expect(query['eq_value'], equals('user_123'));
    });

    test('blockUser inserts into chat_blocks table', () async {
      await profileRepository.blockUser('target_user');

      final query = fakeService.fakeClient.lastQuery;
      expect(query['table'], equals('chat_blocks'));
      expect(query['action'], equals('insert'));
      expect(query['values']['blocker_id'], equals('user_123'));
      expect(query['values']['blocked_id'], equals('target_user'));
    });

    test('unblockUser deletes from chat_blocks table', () async {
      await profileRepository.unblockUser('target_user');

      final query = fakeService.fakeClient.lastQuery;
      expect(query['table'], equals('chat_blocks'));
      expect(query['action'], equals('delete'));
      expect(query['eq_column'], equals('blocked_id'));
      expect(query['eq_value'], equals('target_user'));
    });

    test('muteUser inserts into mutes table', () async {
      await profileRepository.muteUser('target_user');

      final query = fakeService.fakeClient.lastQuery;
      expect(query['table'], equals('mutes'));
      expect(query['action'], equals('insert'));
      expect(query['values']['muter_id'], equals('user_123'));
      expect(query['values']['muted_id'], equals('target_user'));
    });

    test('unmuteUser deletes from mutes table', () async {
      await profileRepository.unmuteUser('target_user');

      final query = fakeService.fakeClient.lastQuery;
      expect(query['table'], equals('mutes'));
      expect(query['action'], equals('delete'));
      expect(query['eq_column'], equals('muted_id'));
      expect(query['eq_value'], equals('target_user'));
    });
  });
}
