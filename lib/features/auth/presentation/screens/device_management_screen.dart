import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../shared/providers/supabase_provider.dart';
import '../../providers/auth_provider.dart';

class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends ConsumerState<DeviceManagementScreen> {
  bool _revoking = false;

  /// Giải mã JWT để lấy session ID của phiên hiện tại (sid claim)
  String? _getCurrentSessionId() {
    try {
      final session = ref.read(supabaseClientProvider).auth.currentSession;
      final token = session?.accessToken;
      if (token == null) return null;
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(decoded) as Map<String, dynamic>;
      return map['sid'] as String?;
    } catch (e) {
      CoreLogger.error('Lỗi khi giải mã JWT để lấy sid: $e', tag: 'DeviceManagement');
      return null;
    }
  }

  Future<void> _revoke(String sessionId, bool isCurrent) async {
    if (isCurrent) {
      // Cảnh báo người dùng nếu tự đăng xuất chính mình
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đăng xuất thiết bị hiện tại?'),
          content: const Text('Hành động này sẽ kết thúc phiên làm việc của bạn trên thiết bị này ngay lập tức.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _revoking = true);
    try {
      if (isCurrent) {
        // Nếu đăng xuất thiết bị hiện tại, gọi signOut để xóa sạch token cục bộ và tự động chuyển hướng về trang login
        await ref.read(authRepositoryProvider).signOut();
      } else {
        // Nếu đăng xuất thiết bị khác, gọi RPC thu hồi session trong DB và tải lại danh sách
        await ref.read(authRepositoryProvider).revokeSession(sessionId);
        ref.invalidate(activeSessionsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đăng xuất thiết bị thành công'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      CoreLogger.error('Lỗi khi thu hồi session: $e', tag: 'DeviceManagement');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể đăng xuất thiết bị: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revoking = false);
    }
  }

  IconData _getDeviceIcon(String ua) {
    final lowerUa = ua.toLowerCase();
    if (lowerUa.contains('windows')) return Icons.desktop_windows_rounded;
    if (lowerUa.contains('macintosh') || lowerUa.contains('mac os')) return Icons.desktop_mac_rounded;
    if (lowerUa.contains('linux') && !lowerUa.contains('android')) return Icons.computer_rounded;
    if (lowerUa.contains('ipad')) return Icons.tablet_mac_rounded;
    if (lowerUa.contains('iphone')) return Icons.phone_iphone_rounded;
    if (lowerUa.contains('android')) return Icons.phone_android_rounded;
    return Icons.devices_rounded;
  }

  String _parseUserAgent(String ua) {
    if (ua.isEmpty) return 'Thiết bị không xác định';
    final lowerUa = ua.toLowerCase();
    
    String os = 'Thiết bị lạ';
    if (lowerUa.contains('windows')) os = 'Windows';
    else if (lowerUa.contains('macintosh') || lowerUa.contains('mac os')) os = 'macOS';
    else if (lowerUa.contains('iphone')) os = 'iPhone';
    else if (lowerUa.contains('ipad')) os = 'iPad';
    else if (lowerUa.contains('android')) os = 'Android';
    else if (lowerUa.contains('linux')) os = 'Linux';

    String browser = '';
    if (lowerUa.contains('chrome')) browser = 'Chrome';
    else if (lowerUa.contains('safari') && !lowerUa.contains('chrome')) browser = 'Safari';
    else if (lowerUa.contains('firefox')) browser = 'Firefox';
    else if (lowerUa.contains('edge')) browser = 'Edge';

    if (browser.isNotEmpty) {
      return '$browser trên $os';
    }
    return os;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(activeSessionsProvider);
    final currentSid = _getCurrentSessionId();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: const Text('Quản lý thiết bị', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.refresh),
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(activeSessionsProvider),
          ),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Text('Không tìm thấy phiên làm việc nào.', style: AppTextStyles.bodyMedium),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeSessionsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final sessionId = session['id'] as String;
                final userAgent = session['user_agent'] as String? ?? '';
                final ip = session['ip'] as String? ?? 'Không rõ IP';
                final updatedAtStr = session['updated_at'] as String?;
                final updatedAt = updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null;
                
                final isCurrent = sessionId == currentSid;
                final deviceIcon = _getDeviceIcon(userAgent);
                final deviceName = _parseUserAgent(userAgent);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2F) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon thiết bị
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : theme.dividerColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            deviceIcon,
                            color: isCurrent ? AppColors.primary : theme.hintColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Thông tin chi tiết
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      deviceName,
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Thiết bị này',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'IP: $ip',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (updatedAt != null)
                                Text(
                                  'Hoạt động ${timeago.format(updatedAt, locale: 'vi')}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Nút đăng xuất từ xa
                        if (_revoking)
                          const CupertinoActivityIndicator()
                        else if (!isCurrent)
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                            tooltip: 'Đăng xuất từ xa',
                            onPressed: () => _revoke(sessionId, isCurrent),
                          )
                        else
                          // Cho phép đăng xuất chính mình qua icon nhưng có cảnh báo
                          IconButton(
                            icon: Icon(Icons.logout_rounded, color: theme.hintColor.withValues(alpha: 0.6)),
                            tooltip: 'Đăng xuất',
                            onPressed: () => _revoke(sessionId, isCurrent),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Đã có lỗi xảy ra: $err', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(activeSessionsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
