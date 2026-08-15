import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/app_toast.dart';
import '../../providers/auth_provider.dart';

class MfaVerificationScreen extends ConsumerStatefulWidget {
  const MfaVerificationScreen({super.key});

  @override
  ConsumerState<MfaVerificationScreen> createState() =>
      _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends ConsumerState<MfaVerificationScreen> {
  static const _buttonBlue = Color(0xFF2563EB);
  static const _disabledBlue = Color(0xFF93B4F5);
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6 || _isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      final factors = await ref.read(authRepositoryProvider).listMfaFactors();
      if (factors.totp.isEmpty) {
        throw const FormatException('Không tìm thấy phương thức xác thực.');
      }
      await ref.read(authRepositoryProvider).verifyMfa(
            factorId: factors.totp.first.id,
            code: code,
          );
      ref.invalidate(mfaFactorsProvider);
      if (mounted) context.go('/feed');
    } catch (_) {
      _codeController.clear();
      if (mounted) {
        ToastService.showError(
          context,
          'Mã không đúng hoặc đã hết hạn. Hãy thử mã mới nhất.',
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.lock_shield_fill,
                      size: 38,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Xác minh danh tính',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nhập mã 6 số đang hiển thị trong ứng dụng xác thực của bạn.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _codeController,
                    autofocus: true,
                    enabled: !_isVerifying,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    onChanged: (value) {
                      setState(() {});
                      if (value.length == 6) _verify();
                    },
                    onSubmitted: (_) => _verify(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 12,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isVerifying ||
                              _codeController.text.trim().length != 6
                          ? null
                          : _verify,
                      style: FilledButton.styleFrom(
                        backgroundColor: _buttonBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _disabledBlue,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isVerifying
                          ? const CupertinoActivityIndicator(
                              color: Colors.white,
                            )
                          : const Text('Tiếp tục'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _isVerifying ? null : _signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: _buttonBlue,
                      disabledForegroundColor: _disabledBlue,
                    ),
                    child: const Text('Đăng xuất và dùng tài khoản khác'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
