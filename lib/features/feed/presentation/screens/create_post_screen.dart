import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

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

  Widget _buildAttachmentToolbar(ThemeData theme) {
    return Row(
      children: [
        IconButton(
          onPressed: _pickImages,
          icon: const Icon(CupertinoIcons.photo),
          color: theme.hintColor.withValues(alpha: 0.6),
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Thêm ảnh',
        ),
        const SizedBox(width: 20),
        IconButton(
          onPressed: _pickVideo,
          icon: const Icon(CupertinoIcons.videocam),
          color: theme.hintColor.withValues(alpha: 0.6),
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Thêm video',
        ),
      ],
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                // Remove button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _media.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Video indicator badge
                if (isVideo)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.play_arrow_solid,
                            size: 8,
                            color: Colors.white,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'VIDEO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'Hủy',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          'Bài viết mới',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: const [
          // Post button moved to bottomNavigationBar for Threads style
          SizedBox(width: 80),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Avatar & Continuous Line
              Column(
                children: [
                  profileAsync.when(
                    data: (profile) => AppAvatar(
                      imageUrl: profile.avatarUrl,
                      name: profile.displayName,
                      radius: 20,
                    ),
                    loading: () => const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                    error: (_, __) => const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.3,
                    child: profileAsync.when(
                      data: (profile) => AppAvatar(
                        imageUrl: profile.avatarUrl,
                        name: profile.displayName,
                        radius: 10,
                      ),
                      loading: () => const CircleAvatar(radius: 10),
                      error: (_, __) => const CircleAvatar(radius: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Right Column: Display Name, Text Input, Media Preview, Quick Toolbar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileAsync.when(
                      data: (profile) => Text(
                        profile.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                    const SizedBox(height: 2),
                    TextField(
                      controller: _captionController,
                      decoration: InputDecoration(
                        hintText: 'Có gì mới?',
                        hintStyle: TextStyle(
                          color: theme.hintColor.withValues(alpha: 0.6),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: null,
                      style: const TextStyle(fontSize: 15),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    _buildMediaPreview(theme),
                    const SizedBox(height: 16),
                    _buildAttachmentToolbar(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.globe,
                  size: 14,
                  color: theme.hintColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  'Bất kỳ ai cũng có thể trả lời',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _captionController,
              builder: (context, _) {
                final hasContent = _captionController.text.trim().isNotEmpty || _media.isNotEmpty;
                return AppButton(
                  label: 'Đăng',
                  onPressed: hasContent ? _post : null,
                  isLoading: _isPosting,
                  width: 80,
                  height: 36,
                  borderRadius: 24,
                  backgroundColor: hasContent 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.primary.withValues(alpha: 0.4),
                );
              },
            ),
          ],
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
