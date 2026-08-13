import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  bool _isSaving = false;

  bool get _hasPasswordLogin {
    final user = ref.read(authRepositoryProvider).currentUser;
    final providers = user?.appMetadata['providers'];
    if (providers is List && providers.contains('email')) return true;
    return user?.identities?.any((identity) => identity.provider == 'email') ?? false;
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _isSaving) return;

    final repository = ref.read(authRepositoryProvider);
    final email = repository.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showMessage('Không tìm thấy email của tài khoản hiện tại.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_hasPasswordLogin) {
        await repository.signIn(
          emailOrUsername: email,
          password: _currentPasswordController.text,
        );
      }
      await repository.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showMessage('Đổi mật khẩu thành công.');
      context.pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials') ||
          message.contains('invalid credentials')) {
        _showMessage(
          'Mật khẩu hiện tại không chính xác. Nếu bạn chỉ đăng nhập bằng Google hoặc Apple, tài khoản có thể chưa có mật khẩu.',
          isError: true,
        );
      } else if (message.contains('same password') || message.contains('different')) {
        _showMessage('Mật khẩu mới phải khác mật khẩu hiện tại.', isError: true);
      } else {
        _showMessage(error.message, isError: true);
      }
    } catch (_) {
      if (mounted) _showMessage('Không thể đổi mật khẩu. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : const Color(0xFF34C759),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    final labelColor = theme.brightness == Brightness.dark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF6C6C70);
    final hasPasswordLogin = _hasPasswordLogin;
    final pageTitle = hasPasswordLogin ? 'Đổi mật khẩu' : 'Thiết lập mật khẩu';

    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        backgroundColor: background.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3), width: 0.5),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : () => context.pop(),
          child: Icon(CupertinoIcons.chevron_back, color: theme.colorScheme.primary, size: 20),
        ),
        middle: Text(pageTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.lock_rotation, color: theme.colorScheme.primary, size: 34),
                ),
                const SizedBox(height: 18),
                Text(
                  'Bảo vệ tài khoản của bạn',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  hasPasswordLogin
                      ? 'Nhập mật khẩu hiện tại để xác minh, sau đó tạo mật khẩu mới.'
                      : 'Tạo mật khẩu để có thể đăng nhập bằng email. Bạn vẫn có thể tiếp tục đăng nhập bằng Google hoặc Apple như bình thường.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: labelColor, height: 1.4),
                ),
                const SizedBox(height: 30),
                if (hasPasswordLogin) ...[
                  _PasswordField(
                    controller: _currentPasswordController,
                    label: 'Mật khẩu hiện tại',
                    obscureText: _hideCurrentPassword,
                    textInputAction: TextInputAction.next,
                    onToggleVisibility: () => setState(() => _hideCurrentPassword = !_hideCurrentPassword),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                ],
                _PasswordField(
                  controller: _newPasswordController,
                  label: 'Mật khẩu mới',
                  obscureText: _hideNewPassword,
                  textInputAction: TextInputAction.next,
                  onToggleVisibility: () => setState(() => _hideNewPassword = !_hideNewPassword),
                  validator: (value) {
                    final error = Validators.password(value);
                    if (error != null) return error;
                    if (hasPasswordLogin && value == _currentPasswordController.text) {
                      return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _PasswordField(
                  controller: _confirmPasswordController,
                  label: 'Xác nhận mật khẩu mới',
                  obscureText: _hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _changePassword(),
                  onToggleVisibility: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                  validator: (value) => Validators.confirmPassword(value, _newPasswordController.text),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(CupertinoIcons.info_circle, size: 17, color: labelColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasPasswordLogin
                            ? 'Mật khẩu phải có ít nhất 6 ký tự. Không sử dụng lại mật khẩu hiện tại.'
                            : 'Sau khi thiết lập, bạn có thể đăng nhập bằng email và mật khẩu hoặc tiếp tục dùng tài khoản liên kết.',
                        style: theme.textTheme.bodySmall?.copyWith(color: labelColor, height: 1.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _changePassword,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(
                            hasPasswordLogin ? 'Cập nhật mật khẩu' : 'Thiết lập mật khẩu',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.textInputAction,
    required this.onToggleVisibility,
    required this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputAction textInputAction;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    textInputAction: textInputAction,
    autofillHints: const [AutofillHints.password],
    autocorrect: false,
    enableSuggestions: false,
    validator: validator,
    onFieldSubmitted: onFieldSubmitted,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(CupertinoIcons.lock),
      suffixIcon: IconButton(
        tooltip: obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: onToggleVisibility,
        icon: Icon(obscureText ? CupertinoIcons.eye : CupertinoIcons.eye_slash),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
    ),
  );
}
