import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class CoreLogger {
  static LogLevel currentLogLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  static void debug(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(LogLevel level, String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    if (level.index < currentLogLevel.index) return;

    final time = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.SSS
    final levelName = level.name.toUpperCase();
    final tagPart = tag != null ? '[$tag]' : '';
    final logMessage = '[$time] $levelName$tagPart: $message';

    // ANSI Colors for console formatting
    String colorCode = '';
    if (!kIsWeb) {
      colorCode = switch (level) {
        LogLevel.debug => '\x1B[36m', // Cyan
        LogLevel.info => '\x1B[32m',  // Green
        LogLevel.warning => '\x1B[33m', // Yellow
        LogLevel.error => '\x1B[31m',   // Red
      };
    }

    final endColor = colorCode.isNotEmpty ? '\x1B[0m' : '';
    final coloredMessage = '$colorCode$logMessage$endColor';

    developer.log(
      coloredMessage,
      name: tag ?? 'MiniSocial',
      error: error,
      stackTrace: stackTrace,
      level: _getDeveloperLogLevel(level),
    );

    // Additionally print to console in debug mode if not captured by dev log
    if (kDebugMode && kIsWeb) {
      print(logMessage);
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
  }

  static int _getDeveloperLogLevel(LogLevel level) {
    return switch (level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
    };
  }
}
