import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';
import 'exceptions.dart';
import 'failure.dart';

class GlobalErrorHandler {
  /// Khởi tạo bộ bắt lỗi toàn cục trong main.dart
  static void initialize() {
    // Bắt lỗi đồng bộ từ Flutter framework
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      CoreLogger.error(
        'Uncaught Flutter Error: ${details.exception}',
        tag: 'GlobalErrorHandler',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    // Bắt lỗi bất đồng bộ từ Platform (Dart VM)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      CoreLogger.error(
        'Uncaught Platform/Async Error: $error',
        tag: 'GlobalErrorHandler',
        error: error,
        stackTrace: stack,
      );
      return true; // Đã xử lý lỗi
    };
  }

  /// Ánh xạ Exception từ Data Layer sang Failure ở Domain Layer
  static Failure handleException(dynamic exception) {
    CoreLogger.warning(
      'Mapping exception to Failure: $exception',
      tag: 'GlobalErrorHandler',
      error: exception is Exception ? exception : null,
    );

    if (exception is AppException) {
      return switch (exception) {
        ServerException() => ServerFailure(exception.message, exception.code),
        CacheException() => CacheFailure(exception.message, exception.code),
        NetworkException() => NetworkFailure(exception.message),
        AuthException() => AuthFailure(exception.message, exception.code),
        ModerationException() => ModerationFailure(exception.message, exception.code),
        ValidationException() => ValidationFailure(exception.message, exception.code),
      };
    }

    // Các lỗi HTTP / Network phổ biến hoặc ngoại lệ không định nghĩa trước
    final errorStr = exception.toString().toLowerCase();
    if (errorStr.contains('socketexception') || errorStr.contains('network_error') || errorStr.contains('failed host lookup')) {
      return const NetworkFailure();
    }

    return UnknownFailure(exception.toString(), 'UNKNOWN_ERROR');
  }
}

/// Widget hiển thị lỗi thân thiện với người dùng
class GlobalErrorWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? code;
  final VoidCallback? onRetry;

  const GlobalErrorWidget({
    super.key,
    this.title = 'Đã xảy ra lỗi',
    required this.message,
    this.code,
    this.onRetry,
  });

  factory GlobalErrorWidget.fromFailure(Failure failure, {VoidCallback? onRetry}) {
    return GlobalErrorWidget(
      title: _getTitleForFailure(failure),
      message: failure.message,
      code: failure.code,
      onRetry: onRetry,
    );
  }

  static String _getTitleForFailure(Failure failure) {
    return switch (failure) {
      NetworkFailure() => 'Lỗi kết nối',
      ServerFailure() => 'Lỗi máy chủ',
      CacheFailure() => 'Lỗi bộ nhớ đệm',
      AuthFailure() => 'Lỗi xác thực',
      ModerationFailure() => 'Nội dung vi phạm',
      ValidationFailure() => 'Dữ liệu không hợp lệ',
      UnknownFailure() => 'Đã xảy ra lỗi',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: isDark ? Colors.redAccent : Colors.red.shade600,
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (code != null && kDebugMode) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Code: $code',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
}
