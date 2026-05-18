import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể gửi email. Thử lại sau'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _sent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Quên mật khẩu', style: AppTextStyles.displayMedium),
        const SizedBox(height: 6),
        Text(
          'Nhập email của bạn để nhận link đặt lại mật khẩu',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).hintColor,
          ),
        ),
        const SizedBox(height: 36),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Email',
                hint: 'example@email.com',
                controller: _emailController,
                validator: Validators.email,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: CupertinoIcons.mail,
                textInputAction: TextInputAction.done,
                onEditingComplete: _sendReset,
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Gửi link đặt lại mật khẩu',
                onPressed: _sendReset,
                isLoading: _isLoading,
                icon: CupertinoIcons.paperplane_fill,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.mail_solid,
              color: Colors.green,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Kiểm tra email của bạn',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 12),
          Text(
            'Chúng tôi đã gửi link đặt lại mật khẩu đến\n${_emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Quay về đăng nhập',
            onPressed: () => context.go('/login'),
          ),
          TextButton(
            onPressed: _sendReset,
            child: const Text('Gửi lại'),
          ),
        ],
      ),
    );
  }
}
