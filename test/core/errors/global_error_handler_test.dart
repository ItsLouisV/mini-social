import 'package:flutter_test/flutter_test.dart';
import 'package:mini_social/core/errors/exceptions.dart';
import 'package:mini_social/core/errors/failure.dart';
import 'package:mini_social/core/errors/global_error_handler.dart';

void main() {
  group('GlobalErrorHandler Exception Mapping Tests', () {
    test('Should map ServerException to ServerFailure', () {
      const exception = ServerException('Database error occurs', 'DB_ERROR');
      final failure = GlobalErrorHandler.handleException(exception);

      expect(failure, isA<ServerFailure>());
      expect(failure.message, equals('Database error occurs'));
      expect(failure.code, equals('DB_ERROR'));
    });

    test('Should map NetworkException to NetworkFailure', () {
      final exception = NetworkException();
      final failure = GlobalErrorHandler.handleException(exception);

      expect(failure, isA<NetworkFailure>());
      expect(failure.message, contains('Không có kết nối Internet'));
    });

    test('Should map generic SocketException string to NetworkFailure', () {
      final exception = Exception('SocketException: Connection failed');
      final failure = GlobalErrorHandler.handleException(exception);

      expect(failure, isA<NetworkFailure>());
    });

    test('Should map unknown exception to UnknownFailure', () {
      final exception = Exception('Something unexpected happened');
      final failure = GlobalErrorHandler.handleException(exception);

      expect(failure, isA<UnknownFailure>());
      expect(failure.code, equals('UNKNOWN_ERROR'));
    });
  });
}
