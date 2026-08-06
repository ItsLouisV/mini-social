import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';
import '../../../social/data/ai_repository.dart';
import '../widgets/image_carousel.dart';

class PostPublishPreviewScreen extends ConsumerStatefulWidget {
  final String caption;
  final List<PostMedia> existingMedia;
  final List<XFile> media;
  final String selectedLayout;
  final String? selectedMusic;
  final String? selectedLocation;
  final String? selectedFeeling;
  final List<String> taggedFriends;
  final String initialPrivacy;
  final PostModel? editPost;

  const PostPublishPreviewScreen({
    super.key,
    required this.caption,
    this.existingMedia = const [],
    this.media = const [],
    required this.selectedLayout,
    this.selectedMusic,
    this.selectedLocation,
    this.selectedFeeling,
    this.taggedFriends = const [],
    this.initialPrivacy = 'public',
    this.editPost,
  });

  @override
  ConsumerState<PostPublishPreviewScreen> createState() =>
      _PostPublishPreviewScreenState();
}

class _PostPublishPreviewScreenState
    extends ConsumerState<PostPublishPreviewScreen> {
  late String _privacy;
  bool _isAiLabelEnabled = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _privacy = widget.initialPrivacy;
    if (widget.editPost != null) {
      _isAiLabelEnabled = widget.editPost!.isAiGenerated;
    }
  }

  bool _isVideo(XFile file) {
    final ext = file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  String _buildFinalCaption() {
    final caption = widget.caption.trim();
    final extraDetails = <String>[];
    if (widget.selectedFeeling != null) {
      extraDetails.add('— đang cảm thấy ${widget.selectedFeeling}');
    }
    if (widget.selectedLocation != null) {
      extraDetails.add('tại ${widget.selectedLocation}');
    }
    if (widget.selectedMusic != null) {
      extraDetails.add('🎵 ${widget.selectedMusic}');
    }
    if (widget.taggedFriends.isNotEmpty) {
      extraDetails.add('cùng ${widget.taggedFriends.join(", ")}');
    }

    String result = caption;
    if (extraDetails.isNotEmpty) {
      result += (result.isNotEmpty ? '\n' : '') + extraDetails.join(' ');
    }

    return result;
  }

  Future<void> _publishPost() async {
    if (_isPosting) return;
    setState(() => _isPosting = true);

    final finalCaption = _buildFinalCaption();

    try {
      // ── AI Pre-Moderation Scan ─────────────────────────────────────
      String? imageBase64;
      String? mimeType;
      if (widget.media.isNotEmpty && !_isVideo(widget.media.first)) {
        try {
          final bytes =
              await ImageCompressor.compressXFile(widget.media.first);
          if (bytes.isNotEmpty) {
            imageBase64 = base64Encode(bytes);
            final ext = widget.media.first.name.split('.').last.toLowerCase();
            mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
          }
        } catch (_) {}
      }

      final modResult = await ref.read(aiRepositoryProvider).moderateContent(
            text: finalCaption,
            imageBase64: imageBase64,
            imageMimeType: mimeType,
          );

      if (!modResult.isSafe ||
          modResult.riskScore >= 70 ||
          modResult.decision == 'REJECT' ||
          modResult.decision == 'BLOCK') {
        final currentUserId = ref.read(currentUserProvider)?.id;
        if (currentUserId != null) {
          ref.read(aiRepositoryProvider).recordViolation(
                userId: currentUserId,
                contentType: 'post',
                violationType: 'nudity_sexual_or_inappropriate',
                riskScore: modResult.riskScore,
                reason: modResult.reason.isNotEmpty
                    ? modResult.reason
                    : 'Nội dung chứa hình ảnh 18+ / vi phạm tiêu chuẩn cộng đồng',
              );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(CupertinoIcons.exclamationmark_shield_fill,
                      color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bài viết bị từ chối (Điểm vi phạm: ${modResult.riskScore}/100).\n${modResult.reason.isNotEmpty ? modResult.reason : "Chứa nội dung nhạy cảm / 18+ không phù hợp tiêu chuẩn."}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final modStatus =
          modResult.decision == 'FLAG' ? 'shadow_limited' : 'published';

      if (widget.editPost != null) {
        await ref.read(postRepositoryProvider).updatePost(
              postId: widget.editPost!.id,
              caption: finalCaption,
              privacy: _privacy,
              layoutType: widget.selectedLayout,
              remainingExistingMedia: widget.existingMedia,
              newMedia: widget.media,
              moderationScore: modResult.riskScore,
              moderationStatus: modStatus,
              isAiGenerated: _isAiLabelEnabled,
            );
        ref.invalidate(feedPostsProvider);
      } else {
        await ref.read(postRepositoryProvider).createPost(
              caption: finalCaption,
              media: widget.media,
              privacy: _privacy,
              layoutType: widget.selectedLayout,
              moderationScore: modResult.riskScore,
              moderationStatus: modStatus,
              isAiGenerated: _isAiLabelEnabled,
            );
      }

      if (mounted) {
        // Đóng về tận Feed
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editPost != null
                ? 'Không thể cập nhật bài viết: ${e.toString()}'
                : 'Không thể đăng bài: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showPrivacyBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.55,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242526) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 12, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đối tượng của bài viết',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Ai có thể nhìn thấy bài viết này của bạn?',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill,
                            size: 26),
                        color: theme.hintColor.withValues(alpha: 0.6),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        _buildPrivacyOptionTile(
                          'public',
                          'Công khai',
                          CupertinoIcons.globe,
                          'Bất kỳ ai cũng có thể xem bài viết này',
                        ),
                        _buildPrivacyOptionTile(
                          'friends',
                          'Bạn bè & Người theo dõi',
                          CupertinoIcons.person_2_fill,
                          'Bạn bè hoặc người đang theo dõi bạn có thể xem',
                        ),
                        _buildPrivacyOptionTile(
                          'private',
                          'Chỉ mình tôi',
                          CupertinoIcons.lock_fill,
                          'Chỉ mình bạn mới có thể xem bài viết này',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyOptionTile(
      String value, String title, IconData icon, String subtitle) {
    final isSelected = _privacy == value;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() => _privacy = value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : theme.hintColor,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(CupertinoIcons.checkmark_alt,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _getPrivacyIcon(String p) {
    switch (p) {
      case 'public':
        return CupertinoIcons.globe;
      case 'friends':
      case 'followers':
        return CupertinoIcons.person_2_fill;
      case 'private':
        return CupertinoIcons.lock_fill;
      default:
        return CupertinoIcons.globe;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));

    final displayCaption = _buildFinalCaption();

    // Prepare all preview media
    final allPreviewMedia = <PostMedia>[
      ...widget.existingMedia,
      ...widget.media.asMap().entries.map((e) {
        final file = e.value;
        final isVideo = _isVideo(file);
        return PostMedia(
          id: 'preview_${e.key}',
          postId: widget.editPost?.id ?? 'preview',
          url: file.path,
          type: isVideo ? 'video' : 'image',
          orderIndex: widget.existingMedia.length + e.key,
          createdAt: DateTime.now(),
        );
      }),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF242526) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back,
              color: theme.textTheme.bodyLarge?.color),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Xem trước & Đăng bài',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Section Title: Bố cục bài viết ─────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text(
                        'Bố cục bài viết chuẩn bị đăng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                        ),
                      ),
                    ),

                    // ── Post Preview Card ─────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242526) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header User
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                profileAsync.when(
                                  data: (profile) => AppAvatar(
                                    imageUrl: profile.avatarUrl,
                                    name: profile.displayName,
                                    radius: 20,
                                  ),
                                  loading: () => const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.transparent),
                                  error: (_, __) => const CircleAvatar(
                                      radius: 20, backgroundColor: Colors.grey),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      profileAsync.when(
                                        data: (profile) => Text(
                                          profile.displayName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        loading: () => const SizedBox(),
                                        error: (_, __) => const SizedBox(),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (_isAiLabelEnabled) ...[
                                            const Text(
                                              'Nội dung do AI tạo',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purpleAccent,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text('•',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme.hintColor)),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            'Vừa xong',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.hintColor,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text('•',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.hintColor)),
                                          const SizedBox(width: 4),
                                          Icon(
                                            _getPrivacyIcon(_privacy),
                                            size: 11,
                                            color: theme.hintColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Caption text
                          if (displayCaption.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                displayCaption,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.3,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Media preview carousel
                          if (allPreviewMedia.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ImageCarousel(
                                media: allPreviewMedia,
                                layoutType: widget.selectedLayout,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Privacy Section ("Ai có thể xem bài viết này") ───
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242526) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: InkWell(
                        onTap: _showPrivacyBottomSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header clickable opens full sheet
                            Row(
                              children: [
                                Icon(_getPrivacyIcon(_privacy),
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Ai có thể xem bài viết này',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 16,
                                  color: theme.hintColor,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Label giá trị đã chọn từ bottomsheet
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF3A3B3C)
                                    : const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(_getPrivacyIcon(_privacy),
                                      color: AppColors.primary, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getPrivacyTitle(_privacy),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getPrivacySubtitle(_privacy),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.hintColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_up_chevron_down,
                                    size: 14,
                                    color: theme.hintColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── AI Label Section ("Gắn nhãn AI") ────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242526) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.sparkles,
                                color: Colors.purpleAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Gắn nhãn AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              CupertinoSwitch(
                                value: _isAiLabelEnabled,
                                activeTrackColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _isAiLabelEnabled = val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Chúng tôi yêu cầu bạn gắn nhãn AI cho một số nội dung nhất định được tạo bởi AI.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Bottom Publish Button ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242526) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPosting ? null : _publishPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: isDark
                        ? const Color(0xFF3A3B3C)
                        : const Color(0xFFE4E6EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.editPost != null ? 'Lưu bài viết' : 'Đăng',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPrivacyTitle(String p) {
    switch (p) {
      case 'public':
        return 'Công khai';
      case 'friends':
      case 'followers':
        return 'Bạn bè và người theo dõi';
      case 'private':
        return 'Chỉ mình tôi';
      default:
        return 'Công khai';
    }
  }

  String _getPrivacySubtitle(String p) {
    switch (p) {
      case 'public':
        return 'Bất kỳ ai ở trong và ngoài Viora';
      case 'friends':
      case 'followers':
        return 'Bạn bè hoặc người đang theo dõi bạn có thể xem';
      case 'private':
        return 'Chỉ mình bạn mới có thể xem bài viết này';
      default:
        return 'Bất kỳ ai ở trong và ngoài Viora';
    }
  }
}
