/// Lớp cơ sở cho tất cả các exception trong hệ thống
sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, [this.code]);

  @override
  String toString() => '$runtimeType: [$code] $message';
}

/// Lỗi từ phía Server / Database (ví dụ: Supabase API, Postgres)
class ServerException extends AppException {
  const ServerException(super.message, [super.code]);
}

/// Lỗi liên quan đến Offline Caching (ví dụ: ObjectBox, SharedPreferences)
class CacheException extends AppException {
  const CacheException(super.message, [super.code]);
}

/// Lỗi mất kết nối mạng hoặc timeout
class NetworkException extends AppException {
  const NetworkException([String message = 'Không có kết nối Internet']) : super(message, 'NETWORK_ERROR');
}

/// Lỗi xác thực tài khoản (ví dụ: sai mật khẩu, tài khoản bị khóa)
class AuthException extends AppException {
  const AuthException(super.message, [super.code]);
}

/// Lỗi kiểm duyệt nội dung (ví dụ: phát hiện hình ảnh/văn bản vi phạm quy chuẩn)
class ModerationException extends AppException {
  const ModerationException(super.message, [super.code]);
}

/// Lỗi đầu vào không hợp lệ từ Client
class ValidationException extends AppException {
  const ValidationException(super.message, [super.code]);
}
