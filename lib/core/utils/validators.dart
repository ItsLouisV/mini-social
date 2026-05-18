class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập email';
    final regex =
        RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
    if (value != password) return 'Mật khẩu không khớp';
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập họ tên';
    if (value.length < 2) return 'Họ tên quá ngắn';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập username';
    if (value.length < 3) return 'Username phải có ít nhất 3 ký tự';
    if (value.length > 30) return 'Username không được quá 30 ký tự';
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(value)) {
      return 'Username chỉ được chứa chữ, số và dấu _';
    }
    return null;
  }

  static String? notEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập $fieldName';
    return null;
  }
}
