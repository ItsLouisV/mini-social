import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../domain/post_model.dart';
import '../../providers/feed_provider.dart';
import '../widgets/image_carousel.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final List<XFile> _media = [];
  bool _isPosting = false;
  String _privacy = 'friends'; // Mặc định Bạn bè giống ảnh FB
  String _selectedLayout = 'panel-top'; // Mặc định cố định panel-top khi >= 3 ảnh/video

  // Extra status items
  String? _selectedMusic;
  String? _selectedLocation;
  String? _selectedFeeling;
  List<String> _taggedFriends = [];
  bool _isInstagramOn = false;
  bool _isThreadsOn = false;

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
    if (caption.isEmpty && _media.isEmpty && _selectedMusic == null && _selectedFeeling == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy viết gì đó hoặc thêm nội dung bài viết')),
      );
      return;
    }

    // Ghép thông tin cảm xúc / vị trí / nhạc vào caption nếu có
    final extraDetails = <String>[];
    if (_selectedFeeling != null) extraDetails.add('— đang cảm thấy $_selectedFeeling');
    if (_selectedLocation != null) extraDetails.add('tại $_selectedLocation');
    if (_selectedMusic != null) extraDetails.add('🎵 $_selectedMusic');
    if (_taggedFriends.isNotEmpty) extraDetails.add('cùng ${_taggedFriends.join(", ")}');

    String finalCaption = caption;
    if (extraDetails.isNotEmpty) {
      finalSuffix: finalCaption += (finalCaption.isNotEmpty ? '\n' : '') + extraDetails.join(' ');
    }

    setState(() => _isPosting = true);
    try {
      await ref.read(postRepositoryProvider).createPost(
            caption: finalCaption,
            media: _media,
            privacy: _privacy,
            layoutType: _selectedLayout,
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
        return AppTranslations.tr(ref, 'public');
      case 'friends':
        return AppTranslations.tr(ref, 'friends');
      case 'followers':
        return AppTranslations.tr(ref, 'followers');
      case 'private':
        return AppTranslations.tr(ref, 'only_me');
      default:
        return AppTranslations.tr(ref, 'friends');
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
        return CupertinoIcons.person_2_fill;
    }
  }

  void _showPrivacyBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF242526) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.hintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Đối tượng của bài viết',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Ai có thể nhìn thấy bài viết này của bạn?',
                style: TextStyle(fontSize: 13, color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              _buildPrivacyTile('public', 'Công khai', CupertinoIcons.globe, 'Bất kỳ ai ở trong và ngoài MiniSocial'),
              _buildPrivacyTile('friends', 'Bạn bè', CupertinoIcons.person_2_fill, 'Chỉ những người bạn của bạn mới có thể xem'),
              _buildPrivacyTile('followers', 'Người theo dõi', CupertinoIcons.person_crop_circle_badge_checkmark, 'Chỉ những người đang theo dõi bạn mới có thể xem'),
              _buildPrivacyTile('private', 'Chỉ mình tôi', CupertinoIcons.lock_fill, 'Chỉ mình bạn mới có thể xem bài viết này'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrivacyTile(String value, String title, IconData icon, String subtitle) {
    final isSelected = _privacy == value;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() => _privacy = value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : theme.hintColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
              const Icon(CupertinoIcons.checkmark_alt, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // Modals for Top Chips
  void _showMusicModal() {
    final songs = ['Việt Nam Ơi', 'Lạc Trôi - Sơn Tùng M-TP', 'Chạy Ngay Đi', 'Ánh Nắng Của Anh', 'Nơi Này Có Anh'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chọn âm nhạc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...songs.map((song) => ListTile(
                    leading: const Icon(CupertinoIcons.music_note_2, color: Colors.purple),
                    title: Text(song),
                    onTap: () {
                      setState(() => _selectedMusic = song);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showLocationModal() {
    final locations = ['Hà Nội', 'TP. Hồ Chí Minh', 'Đà Nẵng', 'Nha Trang', 'Đà Lạt', 'Phú Quốc'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gắn thẻ vị trí', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...locations.map((loc) => ListTile(
                    leading: const Icon(CupertinoIcons.location_solid, color: Colors.redAccent),
                    title: Text(loc),
                    onTap: () {
                      setState(() => _selectedLocation = loc);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showFeelingModal() {
    final feelings = [
      {'label': 'Vui vẻ', 'emoji': '😊'},
      {'label': 'Hạnh phúc', 'emoji': '🥰'},
      {'label': 'Hào hứng', 'emoji': '🥳'},
      {'label': 'Thư giãn', 'emoji': '😌'},
      {'label': 'Mệt mỏi', 'emoji': '😴'},
      {'label': 'Buồn', 'emoji': '😢'},
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cảm xúc / Hoạt động', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: feelings.map((f) => ActionChip(
                      avatar: Text(f['emoji']!, style: const TextStyle(fontSize: 16)),
                      label: Text(f['label']!),
                      onPressed: () {
                        setState(() => _selectedFeeling = '${f['emoji']} ${f['label']}');
                        Navigator.pop(ctx);
                      },
                    )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTagPeopleModal() {
    final friends = ['Phương Linh', 'Văn Nam', 'Hoàng Minh', 'Thu Hà', 'Đức Anh'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gắn thẻ người khác', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...friends.map((friend) {
                    final isTagged = _taggedFriends.contains(friend);
                    return CheckboxListTile(
                      title: Text(friend),
                      value: isTagged,
                      onChanged: (val) {
                        setModalState(() {
                          if (val == true) {
                            _taggedFriends.add(friend);
                          } else {
                            _taggedFriends.remove(friend);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final profileAsync = ref.watch(profileProvider(currentUserId ?? ''));

    final hasContent = _captionController.text.trim().isNotEmpty ||
        _media.isNotEmpty ||
        _selectedMusic != null ||
        _selectedFeeling != null;

    final cardBgColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);
    final chipBgColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);
    final chipTextColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.xmark, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppTranslations.tr(ref, 'new_post'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(CupertinoIcons.ellipsis, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── User Row + Horizontal Chips ───────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        profileAsync.when(
                          data: (profile) => AppAvatar(
                            imageUrl: profile.avatarUrl,
                            name: profile.displayName,
                            radius: 26,
                          ),
                          loading: () => const CircleAvatar(radius: 26, backgroundColor: Colors.transparent),
                          error: (_, __) => const CircleAvatar(radius: 26, backgroundColor: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              profileAsync.when(
                                data: (profile) => Text(
                                  profile.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Top Action Chips Row (Nhạc, Mọi người, Vị trí, Cảm xúc)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTopChip(
                            icon: CupertinoIcons.music_note_2,
                            label: _selectedMusic ?? AppTranslations.tr(ref, 'music'),
                            isSelected: _selectedMusic != null,
                            onTap: _showMusicModal,
                            onClear: _selectedMusic != null
                                ? () => setState(() => _selectedMusic = null)
                                : null,
                            bgColor: chipBgColor,
                            textColor: chipTextColor,
                          ),
                          const SizedBox(width: 8),
                          _buildTopChip(
                            icon: CupertinoIcons.person_2_fill,
                            label: _taggedFriends.isNotEmpty
                                ? '${_taggedFriends.length} ${_privacy == 'friends' ? AppTranslations.tr(ref, 'friends') : AppTranslations.tr(ref, 'people')}'
                                : AppTranslations.tr(ref, 'tag_people'),
                            isSelected: _taggedFriends.isNotEmpty,
                            onTap: _showTagPeopleModal,
                            onClear: _taggedFriends.isNotEmpty
                                ? () => setState(() => _taggedFriends.clear())
                                : null,
                            bgColor: chipBgColor,
                            textColor: chipTextColor,
                          ),
                          const SizedBox(width: 8),
                          _buildTopChip(
                            icon: CupertinoIcons.location_solid,
                            label: _selectedLocation ?? AppTranslations.tr(ref, 'location'),
                            isSelected: _selectedLocation != null,
                            onTap: _showLocationModal,
                            onClear: _selectedLocation != null
                                ? () => setState(() => _selectedLocation = null)
                                : null,
                            bgColor: chipBgColor,
                            textColor: chipTextColor,
                          ),
                          const SizedBox(width: 8),
                          _buildTopChip(
                            icon: CupertinoIcons.smiley_fill,
                            label: _selectedFeeling ?? AppTranslations.tr(ref, 'feeling_activity'),
                            isSelected: _selectedFeeling != null,
                            onTap: _showFeelingModal,
                            onClear: _selectedFeeling != null
                                ? () => setState(() => _selectedFeeling = null)
                                : null,
                            bgColor: chipBgColor,
                            textColor: chipTextColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Text Area ("Bạn đang nghĩ gì?") ───────────────────
                    TextField(
                      controller: _captionController,
                      decoration: InputDecoration(
                        hintText: AppTranslations.tr(ref, 'whats_on_your_mind'),
                        hintStyle: TextStyle(
                          color: isDark ? const Color(0xFF8A8D91) : Colors.grey.shade500,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      minLines: 3,
                      style: const TextStyle(fontSize: 18, height: 1.35),
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),

                    // ── Media Preview ─────────────────────────────────────
                    if (_media.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      // Xem trước trực tiếp Live ImageCarousel tương ứng với 1, 2, hoặc 3+ ảnh
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.15),
                            ),
                          ),
                          child: ImageCarousel(
                            media: _media.asMap().entries.map((e) {
                              final file = e.value;
                              final isVideo = _isVideo(file);
                              return PostMedia(
                                id: 'preview_${e.key}',
                                postId: 'preview',
                                url: file.path,
                                type: isVideo ? 'video' : 'image',
                                orderIndex: e.key,
                                createdAt: DateTime.now(),
                              );
                            }).toList(),
                            layoutType: _selectedLayout,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Danh sách thumbnail nhỏ kèm nút xóa X
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _media.length,
                          itemBuilder: (context, i) {
                            final file = _media[i];
                            final isVideo = _isVideo(file);
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              width: 80,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      color: isDark ? Colors.white10 : Colors.black12,
                                      width: 80,
                                      height: 90,
                                      child: isVideo
                                          ? const Center(child: Icon(CupertinoIcons.play_circle_fill, size: 26, color: Colors.white))
                                          : (kIsWeb
                                              ? Image.network(file.path, fit: BoxFit.cover)
                                              : Image.file(io.File(file.path), fit: BoxFit.cover)),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _media.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(CupertinoIcons.xmark, size: 12, color: Colors.white),
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

                    // ── Layout Selector Bar (Cho 3 ảnh/video trở lên) ─────
                    if (_media.length >= 3) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF242526) : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.layoutDashboard, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  AppTranslations.tr(ref, 'select_layout'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Spacer(),
                                Text(
                                  '${_media.length} ${_media.length == 1 ? AppTranslations.tr(ref, 'posts') : AppTranslations.tr(ref, 'all')}',
                                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildLayoutOptionPill('panel-top', 'Panel Top', LucideIcons.layoutPanelTop, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('dashboard', 'Dashboard', LucideIcons.layoutDashboard, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('columns', 'Columns-3', LucideIcons.columns, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('panel-left', 'Panel Left', LucideIcons.layoutPanelLeft, isDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Attachment Option Cards (Thư viện, GIF, Cột mốc, Trực tiếp) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildOptionCard(
                      icon: CupertinoIcons.photo_on_rectangle,
                      label: AppTranslations.tr(ref, 'gallery'),
                      bgColor: cardBgColor,
                      textColor: chipTextColor,
                      onTap: _pickImages,
                    ),
                    const SizedBox(width: 8),
                    _buildOptionCard(
                      icon: CupertinoIcons.photo,
                      label: AppTranslations.tr(ref, 'gif'),
                      badgeText: 'GIF',
                      bgColor: cardBgColor,
                      textColor: chipTextColor,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('GIF')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildOptionCard(
                      icon: CupertinoIcons.star,
                      label: AppTranslations.tr(ref, 'life_event'),
                      bgColor: cardBgColor,
                      textColor: chipTextColor,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Life Event')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildOptionCard(
                      icon: CupertinoIcons.videocam,
                      label: AppTranslations.tr(ref, 'live'),
                      bgColor: cardBgColor,
                      textColor: chipTextColor,
                      onTap: _pickVideo,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Bottom Toolbar (Bạn bè, Instagram, Threads & Nút Đăng) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Audience selector chip (Bạn bè / Công khai)
                  InkWell(
                    onTap: _showPrivacyBottomSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: chipBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(_getPrivacyIcon(), size: 14, color: chipTextColor),
                          const SizedBox(width: 6),
                          Text(
                            _getPrivacyLabel(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: chipTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Instagram toggle chip
                  InkWell(
                    onTap: () => setState(() => _isInstagramOn = !_isInstagramOn),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isInstagramOn
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : chipBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.camera_fill,
                            size: 14,
                            color: _isInstagramOn ? AppColors.primary : chipTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isInstagramOn ? 'Bật' : 'Tắt',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isInstagramOn ? AppColors.primary : chipTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Threads toggle chip
                  InkWell(
                    onTap: () => setState(() => _isThreadsOn = !_isThreadsOn),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isThreadsOn
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : chipBgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.at,
                            size: 14,
                            color: _isThreadsOn ? AppColors.primary : chipTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isThreadsOn ? 'Bật' : 'Tắt',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isThreadsOn ? AppColors.primary : chipTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Nút Đăng (Post Button) ─────────────────────────
                  ElevatedButton(
                    onPressed: (hasContent && !_isPosting) ? _post : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasContent ? AppColors.primary : (isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB)),
                      disabledBackgroundColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB),
                      foregroundColor: hasContent ? Colors.white : (isDark ? const Color(0xFF8A8D91) : Colors.grey.shade600),
                      elevation: hasContent ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            AppTranslations.tr(ref, 'post_button'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: hasContent ? Colors.white : (isDark ? const Color(0xFF8A8D91) : Colors.grey.shade600),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper cho Top Action Chips
  Widget _buildTopChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onClear,
    required Color bgColor,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.18) : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : textColor,
              ),
            ),
            if (isSelected && onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(CupertinoIcons.xmark_circle_fill, size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper cho Attachment Option Cards (Thư viện, GIF, Cột mốc, Trực tiếp)
  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    String? badgeText,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        height: 72,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            badgeText != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  )
                : Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper cho Layout Option Pills (Lưới vuông, Cột đứng, Nổi bật, Trượt ngang)
  Widget _buildLayoutOptionPill(String layoutKey, String label, IconData icon, bool isDark) {
    final isSelected = _selectedLayout == layoutKey;
    final activeColor = AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedLayout = layoutKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
