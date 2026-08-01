import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/app_video_player.dart';
import '../../domain/post_model.dart';
import 'gallery_screen.dart';

class MediaEditModal extends StatefulWidget {
  final List<PostMedia> existingMedia;
  final List<XFile> media;
  final Function(List<PostMedia> updatedExisting, List<XFile> updatedNew) onSave;

  const MediaEditModal({
    super.key,
    required this.existingMedia,
    required this.media,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PostMedia> existingMedia,
    required List<XFile> media,
    required Function(List<PostMedia> updatedExisting, List<XFile> updatedNew) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaEditModal(
        existingMedia: existingMedia,
        media: media,
        onSave: onSave,
      ),
    );
  }

  @override
  State<MediaEditModal> createState() => _MediaEditModalState();
}

class _MediaEditModalState extends State<MediaEditModal> {
  late List<PostMedia> _existingMedia;
  late List<XFile> _media;

  @override
  void initState() {
    super.initState();
    _existingMedia = List.from(widget.existingMedia);
    _media = List.from(widget.media);
  }

  bool _isVideo(XFile file) {
    final ext = file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(ext);
  }

  Future<void> _pickMoreMedia() async {
    final totalMedia = _existingMedia.length + _media.length;
    if (totalMedia >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 6 ảnh/video cho mỗi bài viết')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultipleMedia();
    if (picked.isEmpty) return;

    final remaining = 6 - totalMedia;
    final toAdd = picked.take(remaining).toList();

    final compressed = <XFile>[];
    for (final x in toAdd) {
      if (!_isVideo(x)) {
        final file = await ImageUtils.compressImage(x);
        compressed.add(file ?? x);
      } else {
        compressed.add(x);
      }
    }

    setState(() {
      _media.addAll(compressed);
    });
  }

  void _saveAndClose() {
    widget.onSave(_existingMedia, _media);
    Navigator.pop(context);
  }

  void _openGallery(int index, List<String> imageUrls) {
    if (imageUrls.isEmpty) return;
    GalleryScreen.open(
      context,
      imageUrls: imageUrls,
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Combine all media items into single list for vertical display
    final totalCount = _existingMedia.length + _media.length;

    // Prepare list of image URLs for full-screen gallery view
    final allImagesOnly = <String>[];
    for (final m in _existingMedia) {
      if (m.type != 'video') allImagesOnly.add(m.url);
    }
    for (final f in _media) {
      if (!_isVideo(f)) allImagesOnly.add(f.path);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18191A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Header với Nút "Xong" góc phải ───────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.xmark, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Chỉnh sửa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _saveAndClose,
                  child: const Text(
                    'Xong',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body: Hiển thị danh sách ảnh/video từ trên xuống ─
          Expanded(
            child: totalCount == 0
                ? Center(
                    child: _buildAddButton(isDark),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: totalCount + 1, // +1 cho nút thêm ở cuối
                    itemBuilder: (context, i) {
                      if (i == totalCount) {
                        // Nút thêm ảnh/video thon gọn ở cuối danh sách
                        if (totalCount >= 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          child: _buildAddButton(isDark),
                        );
                      }

                      final isExisting = i < _existingMedia.length;
                      final String pathOrUrl = isExisting
                          ? _existingMedia[i].url
                          : _media[i - _existingMedia.length].path;
                      final bool isVideo = isExisting
                          ? _existingMedia[i].type == 'video'
                          : _isVideo(_media[i - _existingMedia.length]);

                      final imageIndex = isVideo ? -1 : allImagesOnly.indexOf(pathOrUrl);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isDark ? const Color(0xFF242526) : Colors.black12,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            // ── Khung ảnh/video Full width (không giới hạn khung) ──
                            GestureDetector(
                              onTap: isVideo
                                  ? null
                                  : () => _openGallery(
                                        imageIndex != -1 ? imageIndex : 0,
                                        allImagesOnly,
                                      ),
                              child: isVideo
                                  ? (pathOrUrl.startsWith('http')
                                      ? AppVideoPlayer(url: pathOrUrl)
                                      : Container(
                                          height: 240,
                                          color: Colors.black87,
                                          child: const Center(
                                            child: Icon(
                                              CupertinoIcons.play_circle_fill,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ))
                                  : (pathOrUrl.startsWith('http')
                                      ? Image.network(
                                          pathOrUrl,
                                          fit: BoxFit.fitWidth,
                                          width: double.infinity,
                                        )
                                      : (kIsWeb
                                          ? Image.network(
                                              pathOrUrl,
                                              fit: BoxFit.fitWidth,
                                              width: double.infinity,
                                            )
                                          : Image.file(
                                              io.File(pathOrUrl),
                                              fit: BoxFit.fitWidth,
                                              width: double.infinity,
                                            ))),
                            ),

                            // ── Icon Trash góc phải để xóa ảnh ───────────
                            Positioned(
                              top: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isExisting) {
                                      _existingMedia.removeAt(i);
                                    } else {
                                      _media.removeAt(i - _existingMedia.length);
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white30,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.trash_fill,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: InkWell(
          onTap: _pickMoreMedia,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.squarePlus,
                  color: AppColors.primary,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  'Thêm',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
