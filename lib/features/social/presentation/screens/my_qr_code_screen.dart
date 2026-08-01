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

  Future<void> _saveQrImage(BuildContext context, ProfileModel profile) async {
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
          // Fallback if plugin isn't registered on current dev session
          await Clipboard.setData(ClipboardData(text: 'viora://profile/${profile.id}'));
        }

        if (mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shareSuccess
                          ? 'Đã xuất ảnh mã QR thành công!'
                          : 'Đã tạo ảnh QR & sao chép liên kết vào bộ nhớ tạm!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Không thể tạo ảnh QR: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mã QR của tôi')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem mã QR')),
      );
    }

    final profileAsync = ref.watch(profileProvider(currentUserId));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Wallpaper background (bg2.jpg)
          Image.asset(
            'assets/images/bg2.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0F172A)),
          ),

          // 2. Dark Blur & Gradient Overlay
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

          // 3. Content Body
          SafeArea(
            child: Column(
              children: [
                // Custom Top Bar with Back and Share Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Mã QR của tôi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Direct Image Share Button in Header with FontAwesome arrowUpFromBracket
                      profileAsync.maybeWhen(
                        data: (profile) {
                          return IconButton(
                            onPressed: () => _saveQrImage(context, profile),
                            icon: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.arrowUpFromBracket,
                                color: Colors.white,
                                size: 17,
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

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),

                            // RepaintBoundary to capture QR Card Image
                            RepaintBoundary(
                              key: _qrCardKey,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.28),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // Single Row with Avatar + Name + Username
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
                                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
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
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (profile.username.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '@${profile.username}',
                                                      style: TextStyle(
                                                        color: Colors.white.withValues(alpha: 0.7),
                                                        fontSize: 13,
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
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),

                                        const SizedBox(height: 18),

                                        // QR Code Rendering Container (Smaller size)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.15),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: QrImageView(
                                            data: qrPayload,
                                            version: QrVersions.auto,
                                            size: 175.0,
                                            eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: Color(0xFF0F172A),
                                            ),
                                            dataModuleStyle: const QrDataModuleStyle(
                                              dataModuleShape: QrDataModuleShape.square,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),
                                        Text(
                                          'Mã QR này là của riêng bạn. Khi bạn chia sẻ mã, người khác có thể dùng camera trong Viora để quét mã và kết nối với bạn.',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.75),
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Switch to Scan QR Button (Smaller width, rounded, labeled 'Quét QR')
                            SizedBox(
                              width: 180,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/qr-scan');
                                },
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
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
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
        ],
      ),
    );
  }
}
