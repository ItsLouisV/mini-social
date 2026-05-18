import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
          );

      // Sign out để user phải đăng nhập lại
      await ref.read(authRepositoryProvider).signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký thành công! Hãy đăng nhập để tiếp tục'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_parseError(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String error) {
    debugPrint('''
  ================ ERROR ================
  $error
  ======================================
  ''');

    if (error.contains('already registered') ||
        error.contains('User already registered')) {
      return 'Email này đã được đăng ký';
    }

    return 'Đăng ký thất bại. Vui lòng thử lại';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text('Tạo tài khoản', style: AppTextStyles.displayMedium),
              const SizedBox(height: 6),
              Text(
                'Tham gia MiniSocial ngay hôm nay',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Họ và tên',
                      hint: 'Nguyễn Văn A',
                      controller: _nameController,
                      validator: Validators.fullName,
                      prefixIcon: CupertinoIcons.person,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Email',
                      hint: 'example@email.com',
                      controller: _emailController,
                      validator: Validators.email,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: CupertinoIcons.mail,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Mật khẩu',
                      hint: 'Ít nhất 6 ký tự',
                      controller: _passwordController,
                      validator: Validators.password,
                      obscureText: true,
                      prefixIcon: CupertinoIcons.lock,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Xác nhận mật khẩu',
                      hint: '••••••••',
                      controller: _confirmController,
                      validator: (v) => Validators.confirmPassword(
                          v, _passwordController.text),
                      obscureText: true,
                      prefixIcon: CupertinoIcons.lock,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: _register,
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      label: 'Đăng ký',
                      onPressed: _register,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Đã có tài khoản?',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Theme.of(context).hintColor),
                        ),
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Đăng nhập'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
