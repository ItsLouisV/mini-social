import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';


import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

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

class CreatePostScreen extends ConsumerStatefulWidget {
  final PostModel? editPost;

  const CreatePostScreen({super.key, this.editPost});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late final TextEditingController _captionController;
  List<PostMedia> _existingMedia = [];
  final List<XFile> _media = [];
  String _privacy = 'public'; // Mặc định Công khai
  String _selectedLayout = 'panel-top'; // Mặc định cố định panel-top khi >= 3 ảnh/video

  bool _isGeneratingAICaption = false;

  // Extra status items
  String? _selectedMusic;
  String? _selectedLocation;
  String? _selectedFeeling;
  final List<String> _taggedFriends = [];

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.editPost?.caption ?? '');
    if (widget.editPost != null) {
      _privacy = widget.editPost!.privacy;
      if (widget.editPost!.layoutType.isNotEmpty) {
        _selectedLayout = widget.editPost!.layoutType;
      }
      _existingMedia = List<PostMedia>.from(widget.editPost!.media);
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
        final file = await ImageUtils.compressImage(x);
        compressed.add(file ?? x);
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
      ToastService.showWarning(context, 'Hãy viết gì đó hoặc thêm nội dung bài viết');
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
        final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('PostgrestException: ', '');
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
    required Widget Function(BuildContext ctx, StateSetter setModalState) bodyBuilder,
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
                  color: isDark ? const Color(0xFF242526) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                                if (subtitle != null && subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(fontSize: 12.5, color: theme.hintColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 26),
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

  Future<List<String>> _getRealNearbyLocations() async {
    final List<String> results = [];
    try {
      if (!kIsWeb) {
        final status = await Permission.locationWhenInUse.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          return [];
        }
      }
      final res = await http.get(
        Uri.parse('https://ipapi.co/json/'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final city = data['city'] as String?;
        final region = data['region'] as String?;
        final country = data['country_name'] as String?;
        final lat = data['latitude'];
        final lon = data['longitude'];

        if (city != null && city.isNotEmpty) {
          results.add('$city, $country');
        }
        if (region != null && region.isNotEmpty && region != city) {
          results.add('$region, $country');
        }

        if (lat != null && lon != null) {
          try {
            final nominatimRes = await http.get(
              Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'),
              headers: {'User-Agent': 'VioraApp/1.0'},
            ).timeout(const Duration(seconds: 3));

            if (nominatimRes.statusCode == 200) {
              final nomData = jsonDecode(nominatimRes.body);
              final address = nomData['address'] as Map<String, dynamic>?;
              if (address != null) {
                final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['quarter'];
                final cityDist = address['city_district'] ?? address['county'] ?? address['town'];
                if (suburb != null && city != null) {
                  results.insert(0, '$suburb, $city');
                }
                if (cityDist != null && city != null && cityDist != city) {
                  results.insert(0, '$cityDist, $city');
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return results.toSet().toList();
  }

  void _showLocationModal() {
    String searchQuery = '';
    Future<List<String>>? locationFuture = _getRealNearbyLocations();

    // Lấy vị trí từ ảnh tải lên
    final photoLocations = <String>[];
    if (_media.isNotEmpty) {
      for (int i = 0; i < _media.length; i++) {
        final file = _media[i];
        final cleanName = file.name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(RegExp(r'[_-]'), ' ');
        if (cleanName.length > 3 && !RegExp(r'^\d+$').hasMatch(cleanName)) {
          photoLocations.add('Ảnh ${i + 1}: $cleanName');
        }
      }
      if (photoLocations.isEmpty) {
        photoLocations.add('Ảnh ${_media.first.name.split('.').first}');
      }
    }

    _showCustomFullScreenModal(
      title: 'Gắn thẻ vị trí',
      subtitle: 'Vị trí thực tế từ thiết bị & ảnh đã tải lên',
      heightFactor: 0.92,
      bodyBuilder: (ctx, setModalState) {
        final queryLower = searchQuery.toLowerCase();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm địa điểm...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_thick_circled, size: 18),
                          onPressed: () {
                            setModalState(() => searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: FutureBuilder<List<String>>(
                future: locationFuture,
                builder: (context, snapshot) {
                  final realNearbyLocs = snapshot.data ?? [];
                  final isFetchingLoc = snapshot.connectionState == ConnectionState.waiting;

                  final filteredPhotoLocs = photoLocations.where((l) => l.toLowerCase().contains(queryLower)).toList();
                  final filteredNearbyLocs = realNearbyLocs.where((l) => l.toLowerCase().contains(queryLower)).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // 1. Vị trí từ ảnh tải lên (nếu có)
                      if (_media.isNotEmpty && filteredPhotoLocs.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.photo_fill, size: 16, color: Colors.purpleAccent),
                              SizedBox(width: 8),
                              Text('TỪ ẢNH ĐÃ TẢI LÊN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent)),
                            ],
                          ),
                        ),
                        ...filteredPhotoLocs.map((loc) => ListTile(
                              leading: const Icon(CupertinoIcons.location_north_fill, color: Colors.purpleAccent),
                              title: Text(loc, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Phát hiện từ tệp ảnh', style: TextStyle(fontSize: 12)),
                              trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                              onTap: () {
                                setState(() => _selectedLocation = loc);
                                Navigator.pop(ctx);
                              },
                            )),
                        const Divider(height: 24),
                      ],

                      // 2. Vị trí thiết bị thực tế & xung quanh
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.location_solid, size: 16, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('VỊ TRÍ GỢI Ý', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                      if (isFetchingLoc)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Đang định vị GPS / vị trí thiết bị...', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        )
                      else if (filteredNearbyLocs.isEmpty && searchQuery.isEmpty)
                        const ListTile(
                          leading: Icon(CupertinoIcons.location_slash, color: Colors.grey),
                          title: Text('Không lấy được vị trí GPS thiết bị'),
                          subtitle: Text('Hãy nhập địa điểm vào thanh tìm kiếm trên'),
                        )
                      else
                        ...filteredNearbyLocs.map((loc) => ListTile(
                              leading: const Icon(CupertinoIcons.compass_fill, color: Colors.redAccent),
                              title: Text(loc, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(CupertinoIcons.add, size: 18),
                              onTap: () {
                                setState(() => _selectedLocation = loc);
                                Navigator.pop(ctx);
                              },
                            )),

                      // Tự nhập địa điểm khi có searchQuery
                      if (searchQuery.isNotEmpty) ...[
                        const Divider(height: 24),
                        ListTile(
                          leading: const Icon(CupertinoIcons.add_circled_solid, color: AppColors.primary),
                          title: Text('Sử dụng "$searchQuery"'),
                          subtitle: const Text('Thêm vị trí tùy chỉnh'),
                          onTap: () {
                            setState(() => _selectedLocation = searchQuery);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMusicModal() {
    String searchQuery = '';
    final songs = [
      {'title': 'Việt Nam Ơi', 'artist': 'Minh Beta', 'duration': '3:45'},
      {'title': 'Lạc Trôi', 'artist': 'Sơn Tùng M-TP', 'duration': '3:52'},
      {'title': 'Chạy Ngay Đi', 'artist': 'Sơn Tùng M-TP', 'duration': '4:08'},
      {'title': 'Ánh Nắng Của Anh', 'artist': 'Đức Phúc', 'duration': '4:20'},
      {'title': 'Nơi Này Có Anh', 'artist': 'Sơn Tùng M-TP', 'duration': '4:35'},
      {'title': 'Ngày Đầu Tiên', 'artist': 'Đức Phúc', 'duration': '3:30'},
      {'title': 'Có Chắc Yêu Là Đây', 'artist': 'Sơn Tùng M-TP', 'duration': '3:22'},
    ];

    _showCustomFullScreenModal(
      title: 'Chọn âm nhạc',
      subtitle: 'Thêm bài hát nền cho bài viết của bạn',
      heightFactor: 0.92,
      bodyBuilder: (ctx, setModalState) {
        final queryLower = searchQuery.toLowerCase();
        final filteredSongs = songs.where((s) =>
            s['title']!.toLowerCase().contains(queryLower) ||
            s['artist']!.toLowerCase().contains(queryLower)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bài hát, nghệ sĩ...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_thick_circled, size: 18),
                          onPressed: () {
                            setModalState(() => searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredSongs.length,
                itemBuilder: (context, i) {
                  final song = filteredSongs[i];
                  final isSelected = _selectedMusic == '${song['title']} - ${song['artist']}';
                  return ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.music_note_2, color: Colors.purpleAccent, size: 22),
                    ),
                    title: Text(song['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(song['artist']!),
                    trailing: isSelected
                        ? const Icon(CupertinoIcons.checkmark_alt_circle_fill, color: AppColors.primary)
                        : Text(song['duration']!, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                    onTap: () {
                      setState(() => _selectedMusic = '${song['title']} - ${song['artist']}');
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFeelingModal() {
    String searchQuery = '';
    final feelings = [
      {'label': 'Vui vẻ', 'emoji': '😊'},
      {'label': 'Hạnh phúc', 'emoji': '🥰'},
      {'label': 'Hào hứng', 'emoji': '🥳'},
      {'label': 'Thư giãn', 'emoji': '😌'},
      {'label': 'Tự hào', 'emoji': '😎'},
      {'label': 'Mệt mỏi', 'emoji': '😴'},
      {'label': 'Buồn', 'emoji': '😢'},
      {'label': 'Đang yêu', 'emoji': '😍'},
      {'label': 'Nhớ nhung', 'emoji': '🥺'},
      {'label': 'Chill out', 'emoji': '☕'},
      {'label': 'Đang ăn uống', 'emoji': '🍕'},
      {'label': 'Đang du lịch', 'emoji': '✈️'},
      {'label': 'Đang tập thể thao', 'emoji': '⚽'},
    ];

    _showCustomFullScreenModal(
      title: 'Cảm xúc / Hoạt động',
      subtitle: 'Bạn đang cảm thấy thế nào hôm nay?',
      heightFactor: 0.88,
      bodyBuilder: (ctx, setModalState) {
        final queryLower = searchQuery.toLowerCase();
        final filtered = feelings.where((f) => f['label']!.toLowerCase().contains(queryLower)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm cảm xúc, hoạt động...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(CupertinoIcons.clear_thick_circled, size: 18),
                          onPressed: () {
                            setModalState(() => searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: filtered.map((f) {
                    final labelText = '${f['emoji']} ${f['label']}';
                    final isSelected = _selectedFeeling == labelText;
                    return FilterChip(
                      avatar: Text(f['emoji']!, style: const TextStyle(fontSize: 16)),
                      label: Text(f['label']!),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedFeeling = selected ? labelText : null);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
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

        final friendsAsync = ref.watch(friendsListProvider(currentUserId));

        return friendsAsync.when(
          data: (friendsList) {
            final queryLower = searchQuery.toLowerCase();
            final filteredFriends = friendsList.where((f) =>
                f.displayName.toLowerCase().contains(queryLower) ||
                f.username.toLowerCase().contains(queryLower)).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm bạn bè...',
                      prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(CupertinoIcons.clear_thick_circled, size: 18),
                              onPressed: () {
                                setModalState(() => searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                              style: TextStyle(color: Theme.of(context).hintColor),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredFriends.length,
                          itemBuilder: (context, i) {
                            final friend = filteredFriends[i];
                            final isTagged = _taggedFriends.contains(friend.displayName);
                            return CheckboxListTile(
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                              secondary: AppAvatar(
                                imageUrl: friend.avatarUrl,
                                name: friend.displayName,
                                radius: 18,
                              ),
                              title: Text(friend.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('@${friend.username}', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                              value: isTagged,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    _taggedFriends.add(friend.displayName);
                                  } else {
                                    _taggedFriends.remove(friend.displayName);
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Xong (${_taggedFriends.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Lỗi tải danh sách bạn bè: $err')),
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

    final chipBgColor = isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE4E6EB);
    final chipTextColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? const Color(0xFF18191A) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.xmark, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.editPost != null ? 'Chỉnh sửa bài viết' : AppTranslations.tr(ref, 'new_post'),
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
                                    color: theme.dividerColor.withValues(alpha: 0.15),
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
                                const Icon(Icons.dashboard_outlined, size: 16, color: AppColors.primary),
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
                                  _buildLayoutOptionPill('panel-top', 'Panel Top', Icons.view_agenda_outlined, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('dashboard', 'Dashboard', Icons.dashboard_outlined, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('columns', 'Columns-3', Icons.view_week_outlined, isDark),
                                  const SizedBox(width: 8),
                                  _buildLayoutOptionPill('panel-left', 'Panel Left', Icons.view_sidebar_outlined, isDark),
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
                    iconWidget: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 14, color: Colors.purpleAccent),
                    label: _isGeneratingAICaption ? 'Đang tạo...' : 'AI gợi ý ✨',
                    bgColor: Colors.purple.withValues(alpha: 0.15),
                    textColor: Colors.purpleAccent,
                    onTap: _isGeneratingAICaption ? null : () => _generateAICaption(),
                  ),

                  const SizedBox(width: 4),

                  // 2. Icon Thư viện (FontAwesome image)
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.image, color: AppColors.primary, size: 20),
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
                      icon: const Icon(Icons.gif_box_outlined, color: Colors.green, size: 24),
                      tooltip: 'Ảnh GIF',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tính năng GIF')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.ghost, color: Colors.purple, size: 19),
                      tooltip: 'Cột mốc đáng nhớ',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cột mốc đáng nhớ')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.video, color: Colors.redAccent, size: 19),
                      tooltip: 'Trực tiếp / Video',
                      onPressed: _pickVideo,
                    ),
                  ],

                  const Spacer(),

                  // ── Nút "Tiếp" ─────────────────────────
                  ElevatedButton(
                    onPressed: hasContent ? _goToNextScreen : null,
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
                    child: Text(
                      'Tiếp',
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
  Widget _buildLayoutOptionPill(String layoutKey, String label, IconData icon, bool isDark) {
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
