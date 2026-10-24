import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/image_compressor.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../social/providers/follow_list_provider.dart';
import '../../domain/post_model.dart';
import '../../../social/data/ai_repository.dart';
import '../widgets/image_carousel.dart';
import 'media_edit_modal.dart';
import 'post_publish_preview_screen.dart';
import '../../../location/domain/place_model.dart';
import '../../../location/presentation/location_picker_screen.dart';
import '../../../location/data/photo_location_service.dart';
import '../../../location/providers/location_provider.dart';
import '../../../music/domain/music_track_model.dart';
import '../../../music/presentation/widgets/music_picker_modal.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final PostModel? editPost;

  const CreatePostScreen({super.key, this.editPost});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _FeelingActivityTile extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FeelingActivityTile({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF263449) : const Color(0xFFF7F8FA)),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 23)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(CupertinoIcons.checkmark_circle_fill,
                      color: AppColors.primary, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeelingActivityTab extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FeelingActivityTab({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF34363A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late final TextEditingController _captionController;
  List<PostMedia> _existingMedia = [];
  final List<XFile> _media = [];
  final Map<String, PhotoCoordinates> _photoCoordinates = {};
  String _privacy = 'public'; // Mặc định Công khai
  String _selectedLayout =
      'panel-top'; // Mặc định cố định panel-top khi >= 3 ảnh/video

  bool _isGeneratingAICaption = false;

  // Extra status items
  String? _selectedMusic;
  MusicTrackModel? _selectedMusicTrack;
  PlaceModel? _selectedLocation;
  String? _selectedFeeling;
  final List<String> _taggedFriends = [];

  @override
  void initState() {
    super.initState();
    _captionController =
        TextEditingController(text: widget.editPost?.caption ?? '');
    if (widget.editPost != null) {
      _privacy = widget.editPost!.privacy;
      if (widget.editPost!.layoutType.isNotEmpty) {
        _selectedLayout = widget.editPost!.layoutType;
      }
      _existingMedia = List<PostMedia>.from(widget.editPost!.media);
      _selectedLocation = widget.editPost!.location;
      _selectedMusicTrack = widget.editPost!.musicTrack;
      if (_selectedMusicTrack != null) {
        _selectedMusic =
            '${_selectedMusicTrack!.title} - ${_selectedMusicTrack!.artist}';
      }
    }
  }

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
    ToastService.showWarning(context, 'Tối đa 6 ảnh/video');
  }

  Future<void> _pickMedia() async {
    final totalMedia = _existingMedia.length + _media.length;
    if (totalMedia >= 6) {
      _showMaxMediaSnackBar();
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
        final coordinates =
            await ref.read(photoLocationServiceProvider).readCoordinates(x);
        final file = await ImageUtils.compressImage(x);
        final output = file ?? x;
        compressed.add(output);
        if (coordinates != null) _photoCoordinates[output.path] = coordinates;
      } else {
        compressed.add(x);
      }
    }

    setState(() => _media.addAll(compressed));
  }

  Future<void> _pickVideo() async {
    final totalMedia = _existingMedia.length + _media.length;
    if (totalMedia >= 6) {
      _showMaxMediaSnackBar();
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _media.add(picked));
  }

  void _openMediaEditModal() {
    MediaEditModal.show(
      context,
      existingMedia: _existingMedia,
      media: _media,
      onSave: (updatedExisting, updatedNew) {
        setState(() {
          _existingMedia.clear();
          _existingMedia.addAll(updatedExisting);
          _media.clear();
          _media.addAll(updatedNew);
          _photoCoordinates.removeWhere(
            (path, _) => !updatedNew.any((file) => file.path == path),
          );
        });
      },
    );
  }

  void _goToNextScreen() {
    final caption = _captionController.text.trim();
    if (caption.isEmpty &&
        _existingMedia.isEmpty &&
        _media.isEmpty &&
        _selectedMusic == null &&
        _selectedFeeling == null) {
      ToastService.showWarning(
          context, 'Hãy viết gì đó hoặc thêm nội dung bài viết');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostPublishPreviewScreen(
          caption: _captionController.text,
          existingMedia: _existingMedia,
          media: _media,
          selectedLayout: _selectedLayout,
          selectedMusic: _selectedMusic,
          selectedLocation: _selectedLocation,
          selectedFeeling: _selectedFeeling,
          taggedFriends: _taggedFriends,
          initialPrivacy: _privacy,
          editPost: widget.editPost,
        ),
      ),
    );
  }

  Future<void> _generateAICaption() async {
    setState(() => _isGeneratingAICaption = true);
    try {
      final prompt = _captionController.text.trim();
      String? imageBase64;
      String? mimeType;

      if (_media.isNotEmpty) {
        final firstFile = _media.first;
        if (!_isVideo(firstFile)) {
          final bytes = await ImageCompressor.compressXFile(firstFile);
          imageBase64 = base64Encode(bytes);
          final ext = firstFile.name.split('.').last.toLowerCase();
          mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
        }
      }

      final aiCaption = await ref.read(aiRepositoryProvider).generateCaption(
            textPrompt: prompt.isNotEmpty ? prompt : null,
            imageBase64: imageBase64,
            imageMimeType: mimeType,
          );

      if (mounted) {
        setState(() {
          _captionController.text = aiCaption;
        });
      }
    } catch (e) {
      debugPrint('Error generating AI caption: $e');
      if (mounted) {
        final errorMsg = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('PostgrestException: ', '');
        ToastService.showError(
          context,
          errorMsg.contains('nhạy cảm') || errorMsg.contains('18+')
              ? errorMsg
              : 'Không thể tạo caption AI: $errorMsg',
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAICaption = false);
    }
  }

  void _showCustomFullScreenModal({
    required String title,
    String? subtitle,
    required Widget Function(BuildContext ctx, StateSetter setModalState)
        bodyBuilder,
    double heightFactor = 0.92,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FractionallySizedBox(
              heightFactor: heightFactor,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                        fontSize: 12.5, color: theme.hintColor),
                                  ),
                                ],
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
                      child: bodyBuilder(ctx, setModalState),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showLocationModal() async {
    final selected = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          images: _media,
          photoCoordinates: _media
              .map((file) => _photoCoordinates[file.path])
              .whereType<PhotoCoordinates>()
              .toList(),
        ),
      ),
    );
    if (selected != null && mounted)
      setState(() => _selectedLocation = selected);
  }

  Future<void> _showMusicModal() async {
    final selectedTrack = await MusicPickerModal.show(
      context,
      currentTrack: _selectedMusicTrack,
    );
    if (selectedTrack != null && mounted) {
      setState(() {
        _selectedMusicTrack = selectedTrack;
        _selectedMusic = '${selectedTrack.title} - ${selectedTrack.artist}';
      });
    }
  }

  void _showFeelingModal() {
    String searchQuery = '';
    var activeTab = 0;
    const emotionGroups = <String, List<Map<String, String>>>{
      'Tâm trạng vui': [
        {'label': 'Vui vẻ', 'emoji': '😊'},
        {'label': 'Hạnh phúc', 'emoji': '🥰'},
        {'label': 'Hào hứng', 'emoji': '🤩'},
        {'label': 'Phấn khởi', 'emoji': '🥳'},
        {'label': 'Biết ơn', 'emoji': '🙏'},
        {'label': 'Tự hào', 'emoji': '😎'},
        {'label': 'Được truyền cảm hứng', 'emoji': '✨'},
        {'label': 'Yêu đời', 'emoji': '🌈'},
      ],
      'Tâm trạng bình yên': [
        {'label': 'Thư giãn', 'emoji': '😌'},
        {'label': 'Bình yên', 'emoji': '🕊️'},
        {'label': 'Tập trung', 'emoji': '🧘'},
        {'label': 'Tò mò', 'emoji': '🤔'},
        {'label': 'Hy vọng', 'emoji': '🌱'},
        {'label': 'Buồn ngủ', 'emoji': '😴'},
        {'label': 'Mệt mỏi', 'emoji': '🥱'},
      ],
      'Tâm trạng khác': [
        {'label': 'Đang yêu', 'emoji': '😍'},
        {'label': 'Nhớ nhung', 'emoji': '🥺'},
        {'label': 'Cô đơn', 'emoji': '😔'},
        {'label': 'Buồn', 'emoji': '😢'},
        {'label': 'Lo lắng', 'emoji': '😟'},
        {'label': 'Bối rối', 'emoji': '😵‍💫'},
        {'label': 'Thất vọng', 'emoji': '😞'},
        {'label': 'Tức giận', 'emoji': '😤'},
        {'label': 'Bất ngờ', 'emoji': '😮'},
        {'label': 'Không ổn lắm', 'emoji': '🫠'},
      ],
    };
    const activityGroups = <String, List<Map<String, String>>>{
      'Ăn uống & thư giãn': [
        {'label': 'Đang ăn', 'emoji': '🍽️'},
        {'label': 'Đang uống cà phê', 'emoji': '☕'},
        {'label': 'Đang nấu ăn', 'emoji': '👩‍🍳'},
        {'label': 'Đang xem phim', 'emoji': '🎬'},
        {'label': 'Đang nghe nhạc', 'emoji': '🎧'},
        {'label': 'Đang đọc sách', 'emoji': '📚'},
        {'label': 'Đang chơi game', 'emoji': '🎮'},
        {'label': 'Đang nghỉ ngơi', 'emoji': '🛋️'},
      ],
      'Thể thao & sức khỏe': [
        {'label': 'Đang tập thể dục', 'emoji': '🏋️'},
        {'label': 'Đang chạy bộ', 'emoji': '🏃'},
        {'label': 'Đang đạp xe', 'emoji': '🚴'},
        {'label': 'Đang chơi bóng đá', 'emoji': '⚽'},
        {'label': 'Đang chơi cầu lông', 'emoji': '🏸'},
        {'label': 'Đang bơi', 'emoji': '🏊'},
        {'label': 'Đang tập yoga', 'emoji': '🧘'},
        {'label': 'Đang chăm sóc bản thân', 'emoji': '🧖'},
      ],
      'Công việc & học tập': [
        {'label': 'Đang làm việc', 'emoji': '💻'},
        {'label': 'Đang học', 'emoji': '📖'},
        {'label': 'Đang họp', 'emoji': '🗣️'},
        {'label': 'Đang sáng tạo', 'emoji': '🎨'},
        {'label': 'Đang viết', 'emoji': '✍️'},
        {'label': 'Vừa hoàn thành mục tiêu', 'emoji': '✅'},
      ],
      'Đi chơi & khám phá': [
        {'label': 'Đang du lịch', 'emoji': '✈️'},
        {'label': 'Đang đi chơi', 'emoji': '🚶'},
        {'label': 'Đang ở ngoài', 'emoji': '📍'},
        {'label': 'Đang đi mua sắm', 'emoji': '🛍️'},
        {'label': 'Đang ở cùng bạn bè', 'emoji': '🫂'},
        {'label': 'Đang ở bên gia đình', 'emoji': '🏡'},
        {'label': 'Đang tham dự sự kiện', 'emoji': '🎉'},
        {'label': 'Đang khám phá nơi mới', 'emoji': '🗺️'},
      ],
    };

    _showCustomFullScreenModal(
      title: 'Cảm xúc / Hoạt động',
      subtitle: 'Chia sẻ cảm xúc hoặc việc bạn đang làm',
      heightFactor: 0.92,
      bodyBuilder: (ctx, setModalState) {
        final queryLower = searchQuery.toLowerCase();
        final groups = activeTab == 0 ? emotionGroups : activityGroups;
        final filteredGroups = groups.entries
            .map((entry) => MapEntry(
                  entry.key,
                  entry.value
                      .where((item) =>
                          item['label']!.toLowerCase().contains(queryLower))
                      .toList(),
                ))
            .where((entry) => entry.value.isNotEmpty)
            .toList();
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: TextField(
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:
                      activeTab == 0 ? 'Tìm cảm xúc...' : 'Tìm hoạt động...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_thick_circled,
                              size: 18),
                          onPressed: () =>
                              setModalState(() => searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F3F5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setModalState(() => searchQuery = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _FeelingActivityTab(
                      emoji: '😊',
                      label: 'Cảm xúc',
                      selected: activeTab == 0,
                      isDark: isDark,
                      onTap: () => setModalState(() {
                        activeTab = 0;
                        searchQuery = '';
                      }),
                    ),
                    _FeelingActivityTab(
                      emoji: '✨',
                      label: 'Hoạt động',
                      selected: activeTab == 1,
                      isDark: isDark,
                      onTap: () => setModalState(() {
                        activeTab = 1;
                        searchQuery = '';
                      }),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedFeeling != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.checkmark_circle_fill,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang chọn: $_selectedFeeling',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedFeeling = null),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: filteredGroups.isEmpty
                  ? Center(
                      child: Text(
                        activeTab == 0
                            ? 'Không tìm thấy cảm xúc phù hợp.'
                            : 'Không tìm thấy hoạt động phù hợp.',
                        style: TextStyle(color: Theme.of(ctx).hintColor),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      children: [
                        for (final group in filteredGroups) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              group.key,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(ctx).colorScheme.primary,
                                  ),
                            ),
                          ),
                          for (final item in group.value)
                            _FeelingActivityTile(
                              emoji: item['emoji']!,
                              label: item['label']!,
                              isSelected: _selectedFeeling ==
                                  '${item['emoji']} ${item['label']}',
                              isDark: isDark,
                              onTap: () {
                                final value =
                                    '${item['emoji']} ${item['label']}';
                                setState(() => _selectedFeeling =
                                    _selectedFeeling == value ? null : value);
                                Navigator.pop(ctx);
                              },
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showTagPeopleModal() {
    String searchQuery = '';
    final currentUserId = ref.read(currentUserIdProvider);

    _showCustomFullScreenModal(
      title: 'Gắn thẻ người khác',
      subtitle: 'Chọn bạn bè của bạn trên Viora',
      heightFactor: 0.92,
      bodyBuilder: (ctx, setModalState) {
        if (currentUserId == null || currentUserId.isEmpty) {
          return const Center(child: Text('Bạn chưa đăng nhập'));
        }

        return Consumer(
          builder: (context, modalRef, _) {
            final friendsAsync =
                modalRef.watch(friendsListProvider(currentUserId));
            return friendsAsync.when(
              data: (friendsList) {
                final queryLower = searchQuery.toLowerCase();
                final filteredFriends = friendsList
                    .where((f) =>
                        f.displayName.toLowerCase().contains(queryLower) ||
                        f.username.toLowerCase().contains(queryLower))
                    .toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm bạn bè...',
                          prefixIcon:
                              const Icon(CupertinoIcons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                      CupertinoIcons.clear_thick_circled,
                                      size: 18),
                                  onPressed: () {
                                    setModalState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context).brightness ==
                                  Brightness.dark
                              ? const Color(0xFF0F172A)
                              : Theme.of(context).cardColor,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                    ),
                    Expanded(
                      child: filteredFriends.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  friendsList.isEmpty
                                      ? 'Bạn chưa có bạn bè nào để gắn thẻ.\nHãy kết bạn trên Viora!'
                                      : 'Không tìm thấy bạn bè phù hợp.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Theme.of(context).hintColor),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredFriends.length,
                              itemBuilder: (context, i) {
                                final friend = filteredFriends[i];
                                final isTagged =
                                    _taggedFriends.contains(friend.displayName);
                                return CheckboxListTile(
                                  activeColor: AppColors.primary,
                                  checkColor: Colors.white,
                                  side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.5),
                                      width: 1.5),
                                  secondary: AppAvatar(
                                    imageUrl: friend.avatarUrl,
                                    name: friend.displayName,
                                    radius: 18,
                                  ),
                                  title: Text(friend.displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text('@${friend.username}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).hintColor)),
                                  value: isTagged,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        _taggedFriends.add(friend.displayName);
                                      } else {
                                        _taggedFriends
                                            .remove(friend.displayName);
                                      }
                                    });
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Xong (${_taggedFriends.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_circle,
                          size: 36, color: Colors.orange),
                      const SizedBox(height: 10),
                      const Text('Chưa tải được danh sách bạn bè.'),
                      const SizedBox(height: 4),
                      Text('$err',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).hintColor)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => modalRef
                            .invalidate(friendsListProvider(currentUserId)),
                        icon: const Icon(CupertinoIcons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
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

    final chipBgColor =
        isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);
    final chipTextColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.xmark,
              color: theme.textTheme.bodyLarge?.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.editPost != null
              ? 'Chỉnh sửa bài viết'
              : AppTranslations.tr(ref, 'new_post'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
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
                          loading: () => const CircleAvatar(
                              radius: 26, backgroundColor: Colors.transparent),
                          error: (_, __) => const CircleAvatar(
                              radius: 26, backgroundColor: Colors.grey),
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
                            label: _selectedMusic ??
                                AppTranslations.tr(ref, 'music'),
                            isSelected: _selectedMusic != null,
                            onTap: _showMusicModal,
                            onClear: _selectedMusic != null
                                ? () => setState(() {
                                      _selectedMusic = null;
                                      _selectedMusicTrack = null;
                                    })
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
                            label: _selectedLocation?.name ??
                                AppTranslations.tr(ref, 'location'),
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
                            label: _selectedFeeling ??
                                AppTranslations.tr(ref, 'feeling_activity'),
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
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: AppTranslations.tr(ref, 'whats_on_your_mind'),
                        hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF8A8D91)
                              : Colors.grey.shade500,
                          fontSize: 18,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                      ),
                      maxLines: null,
                      minLines: 6,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),

                    // ── Media Preview ─────────────────────────────────────
                    Builder(
                      builder: (context) {
                        final allPreviewMedia = <PostMedia>[
                          ..._existingMedia,
                          ..._media.asMap().entries.map((e) {
                            final file = e.value;
                            final isVideo = _isVideo(file);
                            return PostMedia(
                              id: 'new_${e.key}',
                              postId: widget.editPost?.id ?? 'preview',
                              url: file.path,
                              type: isVideo ? 'video' : 'image',
                              orderIndex: _existingMedia.length + e.key,
                              createdAt: DateTime.now(),
                            );
                          }),
                        ];

                        if (allPreviewMedia.isEmpty) return const SizedBox();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            // Xem trước trực tiếp Live ImageCarousel
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.dividerColor
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: ImageCarousel(
                                  media: allPreviewMedia,
                                  layoutType: _selectedLayout,
                                  onTapCarousel: _openMediaEditModal,
                                  heroScope: 'create_post',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // ── Layout Selector Bar (Cho 3 ảnh/video trở lên) ─────
                    if (_existingMedia.length + _media.length >= 3) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF242526)
                              : const Color(0xFFF7F8FA),
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
                                const Icon(Icons.dashboard_outlined,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  AppTranslations.tr(ref, 'select_layout'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                                const Spacer(),
                                Text(
                                  '${_media.length} ${_media.length == 1 ? AppTranslations.tr(ref, 'posts') : AppTranslations.tr(ref, 'all')}',
                                  style: TextStyle(
                                      fontSize: 12, color: theme.hintColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildLayoutOptionPill(
                                      'panel-top',
                                      'Panel Top',
                                      Icons.view_agenda_outlined,
                                      isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill(
                                      'dashboard',
                                      'Dashboard',
                                      Icons.dashboard_outlined,
                                      isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('columns', 'Columns-3',
                                      Icons.view_week_outlined, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill(
                                      'panel-left',
                                      'Panel Left',
                                      Icons.view_sidebar_outlined,
                                      isDark),
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

            const Divider(height: 1),

            // ── Bottom Attachment Tools & Nút "Tiếp" ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: isDark ? const Color(0xFF18191A) : Colors.white,
              child: Row(
                children: [
                  // 1. AI gợi ý ✨ (giữ nguyên nút action)
                  _buildOptionCard(
                    iconWidget: const Icon(Icons.auto_awesome,
                        size: 16, color: Colors.purpleAccent),
                    label:
                        _isGeneratingAICaption ? 'Đang tạo...' : 'AI gợi ý ✨',
                    bgColor: Colors.purple.withValues(alpha: 0.15),
                    textColor: Colors.purpleAccent,
                    onTap: _isGeneratingAICaption
                        ? null
                        : () => _generateAICaption(),
                  ),

                  const SizedBox(width: 4),

                  // 2. Icon Thư viện (Material photo_library_outlined)
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined,
                        color: AppColors.primary, size: 22),
                    tooltip: 'Thư viện ảnh & video',
                    onPressed: () {
                      if (_existingMedia.isNotEmpty || _media.isNotEmpty) {
                        _openMediaEditModal();
                      } else {
                        _pickMedia();
                      }
                    },
                  ),

                  // 3, 4, 5. GIF, Cột mốc, Trực tiếp (bị ẩn khi đã chọn ảnh/media)
                  if (_existingMedia.isEmpty && _media.isEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.gif_box_outlined,
                          color: Colors.green, size: 24),
                      tooltip: 'Ảnh GIF',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tính năng GIF')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.flag_outlined,
                          color: Colors.purple, size: 22),
                      tooltip: 'Cột mốc đáng nhớ',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cột mốc đáng nhớ')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.videocam_outlined,
                          color: Colors.redAccent, size: 22),
                      tooltip: 'Trực tiếp / Video',
                      onPressed: _pickVideo,
                    ),
                  ],

                  const Spacer(),

                  // ── Nút "Tiếp" ─────────────────────────
                  ElevatedButton(
                    onPressed: hasContent ? _goToNextScreen : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasContent
                          ? AppColors.primary
                          : (isDark
                              ? const Color(0xFF3A3B3C)
                              : const Color(0xFFE4E6EB)),
                      disabledBackgroundColor: isDark
                          ? const Color(0xFF3A3B3C)
                          : const Color(0xFFE4E6EB),
                      foregroundColor: hasContent
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFF8A8D91)
                              : Colors.grey.shade600),
                      elevation: hasContent ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: Text(
                      'Tiếp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: hasContent
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF8A8D91)
                                : Colors.grey.shade600),
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
          color:
              isSelected ? AppColors.primary.withValues(alpha: 0.18) : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: isSelected ? AppColors.primary : textColor),
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
                child: const Icon(CupertinoIcons.xmark_circle_fill,
                    size: 14, color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper cho Attachment Option Cards (Thư viện, GIF, Cột mốc, Trực tiếp)
  Widget _buildOptionCard({
    required Widget iconWidget,
    required String label,
    String? badgeText,
    required Color bgColor,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badgeText != null
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  )
                : iconWidget,
            const SizedBox(width: 6),
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
  Widget _buildLayoutOptionPill(
      String layoutKey, String label, IconData icon, bool isDark) {
    final isSelected = _selectedLayout == layoutKey;
    const activeColor = AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedLayout = layoutKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
