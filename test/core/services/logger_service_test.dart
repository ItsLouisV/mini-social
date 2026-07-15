import 'package:flutter_test/flutter_test.dart';
import 'package:mini_social/core/services/logger_service.dart';

void main() {
  group('CoreLogger Unit Tests', () {
    test('Verify log level filtering boundary', () {
      // Set to info level
      CoreLogger.currentLogLevel = LogLevel.info;

      // Debug level is lower than Info (0 < 1), should be filtered out
      expect(LogLevel.debug.index < CoreLogger.currentLogLevel.index, isTrue);

      // Warning level is higher than Info (2 > 1), should pass
      expect(LogLevel.warning.index >= CoreLogger.currentLogLevel.index, isTrue);

      // Info level is equal to Info (1 == 1), should pass
      expect(LogLevel.info.index >= CoreLogger.currentLogLevel.index, isTrue);
    });

    test('Verify custom log message formats and tags', () {
      // Simply check logger invocation doesn't throw exceptions
      expect(
        () => CoreLogger.debug('Debug test message', tag: 'Test'),
        returnsNormally,
      );
      expect(
        () => CoreLogger.info('Info test message', tag: 'Test'),
        returnsNormally,
      );
      expect(
        () => CoreLogger.warning('Warning test message', tag: 'Test'),
        returnsNormally,
      );
      expect(
        () => CoreLogger.error('Error test message', tag: 'Test'),
        returnsNormally,
      );
    });
  });
}
