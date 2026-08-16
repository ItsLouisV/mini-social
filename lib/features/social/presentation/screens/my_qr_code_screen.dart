import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/error_widget.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../profile/providers/profile_provider.dart';

class MyQrCodeScreen extends ConsumerStatefulWidget {
  const MyQrCodeScreen({super.key});

  @override
  ConsumerState<MyQrCodeScreen> createState() => _MyQrCodeScreenState();
}

class _MyQrCodeScreenState extends ConsumerState<MyQrCodeScreen> {
  final GlobalKey _qrCardKey = GlobalKey();

  Future<void> _saveQrImage(ProfileModel profile) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes != null) {
        bool shareSuccess = false;
        try {
          final xFile = XFile.fromData(
            pngBytes,
            name: 'viora_qr_${profile.username.isNotEmpty ? profile.username : profile.id}.png',
            mimeType: 'image/png',
          );
          await Share.shareXFiles([xFile], text: 'Mã QR Viora của ${profile.displayName}');
          shareSuccess = true;
        } catch (_) {
          await Clipboard.setData(ClipboardData(text: 'viora://profile/${profile.id}'));
        }

        if (!mounted) return;
        ToastService.showSuccess(
          context,
          shareSuccess
              ? 'Đã xuất ảnh mã QR thành công!'
              : 'Đã tạo ảnh QR & sao chép liên kết vào bộ nhớ tạm!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Không thể tạo ảnh QR: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final currentUserId = ref.watch(currentUserIdProvider);

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mã QR của tôi')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem mã QR')),
      );
    }

    final profileAsync = ref.watch(profileProvider(currentUserId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Icon(
                          CupertinoIcons.chevron_back,
                          color: colorScheme.onSurface,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mã QR của tôi',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),

                  // Share Button
                  profileAsync.maybeWhen(
                    data: (profile) {
                      return IconButton(
                        onPressed: () => _saveQrImage(profile),
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: FaIcon(
                            FontAwesomeIcons.arrowUpFromBracket,
                            color: colorScheme.onPrimaryContainer,
                            size: 16,
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: profileAsync.when(
                data: (profile) {
                  final qrPayload = 'viora://profile/${profile.id}';

                  // Đảm bảo mã QR luôn dùng mảng đen trên nền trắng tiêu chuẩn để
                  // các thư viện quét QR (ML Kit / Camera / Gallery decoder) đọc được 100%
                  const qrForegroundColor = Color(0xFF0F172A);
                  const qrBackgroundColor = Colors.white;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // QR Card
                        RepaintBoundary(
                          key: _qrCardKey,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withValues(alpha: isDark ? 0.4 : 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Avatar + Name row
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: AppAvatar(
                                        imageUrl: profile.avatarUrl,
                                        name: profile.displayName,
                                        radius: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            profile.displayName,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (profile.username.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '@${profile.username}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Text(
                                  'Người liên hệ trên Viora.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 18),

                                // QR Code
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: qrBackgroundColor,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: qrPayload,
                                    version: QrVersions.auto,
                                    size: 175.0,
                                    backgroundColor: qrBackgroundColor,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: qrForegroundColor,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: qrForegroundColor,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),
                                Text(
                                  'Mã QR này là của riêng bạn. Khi bạn chia sẻ mã, người khác có thể dùng camera trong Viora để quét mã và kết nối với bạn.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Scan QR Button
                        SizedBox(
                          width: 180,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/qr-scan'),
                            icon: const Icon(CupertinoIcons.qrcode_viewfinder, color: Colors.white, size: 20),
                            label: const Text(
                              'Quét QR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 4,
                              shadowColor: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
                error: (e, _) => AppErrorWidget(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(profileProvider(currentUserId)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
