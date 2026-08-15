import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/app_toast.dart';
import '../../providers/auth_provider.dart';

class TwoFactorAuthScreen extends ConsumerStatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  ConsumerState<TwoFactorAuthScreen> createState() =>
      _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends ConsumerState<TwoFactorAuthScreen> {
  static const _buttonBlue = Color(0xFF2563EB);
  static const _disabledBlue = Color(0xFF93B4F5);
  static const _dangerRed = Color(0xFFDC2626);
  final _codeController = TextEditingController();
  AuthMFAEnrollResponse? _enrollment;
  bool _isBusy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _beginEnrollment() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final existing = await repository.listMfaFactors();
      for (final factor in existing.all
          .where((factor) => factor.status == FactorStatus.unverified)) {
        await repository.removeMfaFactor(factor.id);
      }
      final enrollment = await repository.enrollTotp();
      if (mounted) setState(() => _enrollment = enrollment);
    } catch (error) {
      if (mounted) {
        ToastService.showError(context, 'Không thể bắt đầu thiết lập: $error');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmEnrollment() async {
    final enrollment = _enrollment;
    final code = _codeController.text.trim();
    if (enrollment == null || code.length != 6 || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(authRepositoryProvider).verifyMfa(
            factorId: enrollment.id,
            code: code,
          );
      _codeController.clear();
      _enrollment = null;
      ref.invalidate(mfaFactorsProvider);
      if (mounted) {
        setState(() {});
        ToastService.showSuccess(context, 'Đã bật xác thực 2 bước.');
      }
    } catch (_) {
      _codeController.clear();
      if (mounted) {
        ToastService.showError(context, 'Mã không đúng. Hãy nhập mã mới nhất.');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _disable(Factor factor) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Tắt xác thực 2 bước?'),
        content: const Text(
          'Tài khoản của bạn sẽ chỉ còn được bảo vệ bằng phương thức đăng nhập chính.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => dialogContext.pop(false),
            child: const Text('Hủy'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => dialogContext.pop(true),
            child: const Text('Tắt'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(authRepositoryProvider).removeMfaFactor(factor.id);
      ref.invalidate(mfaFactorsProvider);
      if (mounted) ToastService.showSuccess(context, 'Đã tắt xác thực 2 bước.');
    } catch (error) {
      if (mounted) {
        ToastService.showError(
          context,
          'Hãy xác minh mã 2 bước trong phiên này trước khi tắt.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final factors = ref.watch(mfaFactorsProvider);
    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Xác thực 2 bước'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.chevron_back, color: _buttonBlue),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: factors.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, _) => Center(
              child: FilledButton.tonal(
                onPressed: () => ref.invalidate(mfaFactorsProvider),
                style: FilledButton.styleFrom(
                  backgroundColor: _buttonBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Thử tải lại'),
              ),
            ),
            data: (result) => _enrollment != null
                ? _buildEnrollment(theme, _enrollment!)
                : _buildStatus(theme, result.totp),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(ThemeData theme, List<Factor> factors) {
    final enabled = factors.isNotEmpty;
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: enabled
                ? colors.primaryContainer.withValues(alpha: .65)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(children: [
            Icon(
              enabled
                  ? CupertinoIcons.checkmark_shield_fill
                  : CupertinoIcons.lock_shield,
              size: 48,
              color: enabled ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              enabled ? 'Đang được bảo vệ' : 'Tăng cường bảo mật tài khoản',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              enabled
                  ? 'Mỗi lần đăng nhập trên phiên mới, bạn cần nhập thêm mã từ ứng dụng xác thực.'
                  : 'Ngay cả khi mật khẩu bị lộ, người khác vẫn không thể đăng nhập nếu thiếu mã xác thực.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: colors.onSurfaceVariant,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        if (!enabled)
          FilledButton.icon(
            onPressed: _isBusy ? null : _beginEnrollment,
            icon: const Icon(CupertinoIcons.shield_lefthalf_fill),
            label: const Text('Thiết lập ngay'),
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
          )
        else
          ...factors.map((factor) => Card(
                elevation: 0,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(CupertinoIcons.device_phone_portrait),
                  ),
                  title: Text(factor.friendlyName ?? 'Ứng dụng xác thực'),
                  subtitle: const Text('TOTP • Đang hoạt động'),
                  trailing: TextButton(
                    onPressed: _isBusy ? null : () => _disable(factor),
                    style: TextButton.styleFrom(
                      foregroundColor: _dangerRed,
                      disabledForegroundColor:
                          _dangerRed.withValues(alpha: .45),
                    ),
                    child: const Text('Tắt'),
                  ),
                ),
              )),
        const SizedBox(height: 20),
        const _InfoRow(
          icon: CupertinoIcons.timer,
          text: 'Mã tự thay đổi khoảng mỗi 30 giây.',
        ),
        const _InfoRow(
          icon: CupertinoIcons.exclamationmark_triangle,
          text: 'Không chia sẻ mã hoặc khóa thiết lập với bất kỳ ai.',
        ),
      ],
    );
  }

  Widget _buildEnrollment(ThemeData theme, AuthMFAEnrollResponse enrollment) {
    final totp = enrollment.totp!;
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Quét mã QR',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Mở ứng dụng Authenticator, thêm tài khoản mới rồi quét mã bên dưới.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(height: 1.45, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: QrImageView(data: totp.uri, size: 210),
          ),
        ),
        const SizedBox(height: 18),
        Text('Không quét được?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: totp.secret));
            if (mounted) ToastService.showSuccess(context, 'Đã sao chép khóa.');
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  totp.secret,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Icon(CupertinoIcons.doc_on_doc, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        Text('Nhập mã để hoàn tất', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        TextField(
          controller: _codeController,
          enabled: !_isBusy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _confirmEnrollment(),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Mã xác thực gồm 6 số',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _isBusy || _codeController.text.trim().length != 6
              ? null
              : _confirmEnrollment,
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
          child: _isBusy
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Text('Xác nhận và bật'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
