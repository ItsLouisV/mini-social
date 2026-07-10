import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../providers/feed_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final List<XFile> _media = [];
  bool _isPosting = false;
  String _privacy = 'public';

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool _isVideo(XFile file) {
    final ext = file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  void _showMaxMediaSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tối đa 5 ảnh hoặc video')),
    );
  }

  Future<void> _pickImages() async {
    if (_media.length >= 5) {
      _showMaxMediaSnackBar();
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final remaining = 5 - _media.length;
    final toAdd = picked.take(remaining).toList();

    final compressed = <XFile>[];
    for (final x in toAdd) {
      final file = await ImageUtils.compressImage(x);
      compressed.add(file ?? x);
    }

    setState(() => _media.addAll(compressed));
  }

  Future<void> _pickVideo() async {
    if (_media.length >= 5) {
      _showMaxMediaSnackBar();
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _media.add(picked));
  }

  Future<void> _post() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _media.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy viết gì đó hoặc thêm ảnh/video')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      await ref.read(postRepositoryProvider).createPost(
            caption: caption,
            media: _media,
            privacy: _privacy,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  String _getPrivacyLabel() {
    switch (_privacy) {
      case 'public':
        return 'Công khai';
      case 'friends':
        return 'Bạn bè';
      case 'followers':
        return 'Người theo dõi';
      case 'private':
        return 'Riêng tư';
      default:
        return 'Công khai';
    }
  }

  IconData _getPrivacyIcon() {
    switch (_privacy) {
      case 'public':
        return CupertinoIcons.globe;
      case 'friends':
        return CupertinoIcons.person_2_fill;
      case 'followers':
        return CupertinoIcons.person_crop_circle_badge_checkmark;
      case 'private':
        return CupertinoIcons.lock_fill;
      default:
        return CupertinoIcons.globe;
    }
  }

  void _showPrivacyBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(isDark ? 0.6 : 0.4),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.15),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: ListView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.hintColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chọn chế độ bài đăng',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ai có thể nhìn thấy bài viết này của bạn?',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPrivacyOption(ctx, 'public', 'Công khai', CupertinoIcons.globe, 'Bất kỳ ai ở trong và ngoài MiniSocial'),
                  _buildPrivacyOption(ctx, 'friends', 'Bạn bè', CupertinoIcons.person_2_fill, 'Chỉ những người bạn của bạn mới có thể xem'),
                  _buildPrivacyOption(ctx, 'followers', 'Người theo dõi', CupertinoIcons.person_crop_circle_badge_checkmark, 'Chỉ những người đang theo dõi bạn mới có thể xem'),
                  _buildPrivacyOption(ctx, 'private', 'Riêng tư', CupertinoIcons.lock_fill, 'Chỉ mình bạn mới có thể xem bài viết này'),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPrivacyOption(
    BuildContext ctx,
    String value,
    String label,
    IconData icon,
    String description,
  ) {
    final theme = Theme.of(ctx);
    final isSelected = _privacy == value;
    
    return GestureDetector(
      onTap: () {
        setState(() => _privacy = value);
        Navigator.of(ctx).pop();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : theme.scaffoldBackgroundColor.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.dividerColor.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.dividerColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : theme.hintColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: theme.colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentToolbar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.dividerColor.withOpacity(isDark ? 0.05 : 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            'Thêm vào bài đăng:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.hintColor.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _ToolbarButton(
            icon: CupertinoIcons.photo_fill_on_rectangle_fill,
            color: const Color(0xFF9B59B6),
            tooltip: 'Thêm ảnh',
            onTap: _pickImages,
          ),
          const SizedBox(width: 12),
          _ToolbarButton(
            icon: CupertinoIcons.videocam_circle,
            color: const Color(0xFF3A5BDB),
            tooltip: 'Thêm video',
            iconSize: 23,
            onTap: _pickVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(ThemeData theme) {
    if (_media.isEmpty) return const SizedBox();

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        itemBuilder: (context, i) {
          final file = _media[i];
          final isVideo = _isVideo(file);
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 135,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      width: 135,
                      height: 180,
                      child: isVideo
                          ? _LocalVideoPreview(file: file)
                          : (kIsWeb
                              ? Image.network(file.path, fit: BoxFit.cover)
                              : Image.file(io.File(file.path), fit: BoxFit.cover)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _media.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.play_arrow_solid,
                            size: 8,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VIDEO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final isDark = theme.brightness == Brightness.dark;
    
    final pageBg = isDark
        ? const Color(0xFF12121A)
        : const Color(0xFFF8F9FD);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'Hủy',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        title: Text(
          'Bài viết mới',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  profileAsync.when(
                    data: (profile) => AppAvatar(
                      imageUrl: profile.avatarUrl,
                      name: profile.displayName,
                      radius: 22,
                    ),
                    loading: () => const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.transparent,
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                    error: (_, __) => const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profileAsync.when(
                          data: (profile) => Text(
                            profile.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: _showPrivacyBottomSheet,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getPrivacyIcon(),
                                    size: 12,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPrivacyLabel(),
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    CupertinoIcons.chevron_down,
                                    size: 10,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              TextField(
                controller: _captionController,
                decoration: InputDecoration(
                  hintText: 'Có gì mới thế?',
                  hintStyle: TextStyle(
                    color: theme.hintColor.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? theme.scaffoldBackgroundColor
                      : theme.scaffoldBackgroundColor.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.15),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.15),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.6),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLines: null,
                minLines: 4,
                style: const TextStyle(fontSize: 16, height: 1.4),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              _buildMediaPreview(theme),
              const SizedBox(height: 20),
              _buildAttachmentToolbar(theme),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withOpacity(isDark ? 0.05 : 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 14,
                  color: theme.hintColor.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Bất kỳ ai cũng có thể trả lời',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _captionController,
              builder: (context, _) {
                final hasContent = _captionController.text.trim().isNotEmpty || _media.isNotEmpty;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                
                final bgColor = hasContent
                    ? AppColors.chatInputSendEnabled
                    : (isDark
                        ? AppColors.darkChatInputSendDisabled
                        : AppColors.chatInputSendDisabled);
                final textColor = hasContent
                    ? AppColors.chatInputSendIconEnabled
                    : AppColors.chatInputSendIconDisabled;

                return GestureDetector(
                  onTap: hasContent && !_isPosting ? _post : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: hasContent
                          ? LinearGradient(
                              colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: hasContent ? null : bgColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: hasContent
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: _isPosting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Đăng',
                              style: TextStyle(
                                color: hasContent ? Colors.white : textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final double iconSize;

  const _ToolbarButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.iconSize = 19,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalVideoPreview extends StatefulWidget {
  final XFile file;
  const _LocalVideoPreview({required this.file});

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    if (kIsWeb) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.file.path));
    } else {
      _controller = VideoPlayerController.file(io.File(widget.file.path));
    }
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(0); // Muted preview
      _controller.play();
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing local video preview: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
