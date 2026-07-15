/// Lớp cơ sở cho tất cả các Failure trong tầng Domain
sealed class Failure {
  final String message;
  final String? code;

  const Failure(this.message, [this.code]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;

  @override
  String toString() => '$runtimeType: [$code] $message';
}

/// Lỗi kết nối mạng từ phía máy khách
class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Kết nối mạng không ổn định. Vui lòng kiểm tra lại.']) : super(message, 'NETWORK_FAILURE');
}

/// Lỗi phản hồi từ máy chủ Supabase / Edge Functions
class ServerFailure extends Failure {
  const ServerFailure(super.message, [super.code]);
}

/// Lỗi liên quan đến cơ sở dữ liệu ngoại tuyến ObjectBox
class CacheFailure extends Failure {
  const CacheFailure(super.message, [super.code]);
}

/// Lỗi xảy ra trong quá trình xác thực / Đăng nhập
class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.code]);
}

/// Lỗi kiểm duyệt nội dung của bài đăng
class ModerationFailure extends Failure {
  const ModerationFailure(super.message, [super.code]);
}

/// Lỗi dữ liệu không hợp lệ
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, [super.code]);
}

/// Lỗi chung không xác định
class UnknownFailure extends Failure {
  const UnknownFailure(super.message, [super.code]);
}
