import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../music/domain/music_track_model.dart';
import '../../../music/presentation/widgets/music_picker_modal.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../providers/story_provider.dart';

class CreateStoryModal extends ConsumerStatefulWidget {
  const CreateStoryModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateStoryModal(),
    );
  }

  @override
  ConsumerState<CreateStoryModal> createState() => _CreateStoryModalState();
}

class _CreateStoryModalState extends ConsumerState<CreateStoryModal> {
  final TextEditingController _captionController = TextEditingController();
  XFile? _selectedImage;
  MusicTrackModel? _selectedMusicTrack;
  String _selectedBgColor = '#1C1C1E';
  bool _isPublishing = false;

  final List<Map<String, String>> _colorPalettes = [
    {'name': 'Đêm thẫm', 'color': '#1C1C1E'},
    {'name': 'Tím Neon', 'color': '#3B0764'},
    {'name': 'Xanh Biển', 'color': '#0369A1'},
    {'name': 'Hoàng Hôn', 'color': '#991B1B'},
    {'name': 'Ngọc Lục', 'color': '#065F46'},
    {'name': 'Ánh Hồng', 'color': '#831843'},
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _pickMusic() async {
    final track = await MusicPickerModal.show(
      context,
      currentTrack: _selectedMusicTrack,
    );
    if (track != null && mounted) {
      setState(() => _selectedMusicTrack = track);
    }
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _publishStory() async {
    final caption = _captionController.text.trim();
    if (_selectedImage == null && caption.isEmpty && _selectedMusicTrack == null) {
      ToastService.showWarning(context, 'Hãy thêm hình ảnh, viết gì đó hoặc chọn bài hát');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      await ref.read(storyRepositoryProvider).createStory(
            imageFile: _selectedImage,
            caption: caption.isNotEmpty ? caption : null,
            musicTrack: _selectedMusicTrack,
            backgroundColor: _selectedBgColor,
          );

      ref.invalidate(activeStoriesProvider);

      if (mounted) {
        ToastService.showSuccess(context, 'Đã đăng tin mới!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(context, 'Không thể đăng tin: $e');
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));
    final bgColor = _hexToColor(_selectedBgColor);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.98,
        color: bgColor,
        child: Stack(
          children: [
            // Layer 1: FULLSCREEN IMAGE BACKGROUND (if image picked) or COLOR CANVAS
            if (_selectedImage != null)
              Positioned.fill(
                child: kIsWeb
                    ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                    : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
              )
            else
              Positioned.fill(
                child: Container(color: bgColor),
              ),

            // Subtle dark gradient overlay over image to ensure text legibility
            if (_selectedImage != null)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black45,
                        Colors.transparent,
                        Colors.black54,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

            // Layer 2: TRANSPARENT TEXT INPUT CANVAS (In center, 100% background-free)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _captionController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(blurRadius: 10, color: Colors.black87),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Chạm để viết văn bản...',
                    hintStyle: TextStyle(
                      color: Colors.white60,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black87),
                      ],
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                  ),
                ),
              ),
            ),

            // Layer 3: FLOATING TOP HEADER BAR (Glassmorphic Header)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 8),
                      profileAsync.when(
                        data: (profile) => AppAvatar(
                          imageUrl: profile.avatarUrl,
                          name: profile.displayName,
                          radius: 16,
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: profileAsync.when(
                          data: (profile) => Text(
                            profile.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                      if (_selectedImage != null)
                        IconButton(
                          onPressed: () => setState(() => _selectedImage = null),
                          icon: const Icon(CupertinoIcons.trash, color: Colors.white70, size: 20),
                        ),
                      ElevatedButton(
                        onPressed: _isPublishing ? null : _publishStory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        ),
                        child: _isPublishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Đăng tin',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Layer 4: FLOATING MUSIC CHIP (If Music Selected)
            if (_selectedMusicTrack != null)
              Positioned(
                top: 75,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.music_note_2, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${_selectedMusicTrack!.title} • ${_selectedMusicTrack!.artist}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _selectedMusicTrack = null),
                          child: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white70, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Layer 5: FLOATING BOTTOM ACTION TOOLBAR
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Color Palettes Row (only if image not selected)
                    if (_selectedImage == null) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _colorPalettes.map((p) {
                            final isSelected = _selectedBgColor == p['color'];
                            final color = _hexToColor(p['color']!);
                            return GestureDetector(
                              onTap: () => setState(() => _selectedBgColor = p['color']!),
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white24,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action buttons: Pick Photo & Pick Music
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(CupertinoIcons.photo, color: Colors.white, size: 18),
                          label: Text(_selectedImage != null ? 'Đổi ảnh' : 'Hình ảnh', style: const TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            backgroundColor: Colors.black45,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickMusic,
                          icon: const Icon(CupertinoIcons.music_note_2, color: Color(0xFF38BDF8), size: 18),
                          label: Text(
                            _selectedMusicTrack != null ? 'Đổi nhạc' : 'Thêm nhạc',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            backgroundColor: Colors.black45,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
