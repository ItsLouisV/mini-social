import 'dart:io' as io;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';


import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _customInterestController = TextEditingController();

  bool _isLoading = false;
  XFile? _newAvatar;
  XFile? _newCover;
  bool _initialized = false;
  List<String> _selectedInterests = [];

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _customInterestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider)!;
    final profileAsync = ref.watch(profileProvider(currentUserId));

    return profileAsync.when(
      data: (profile) {
        if (!_initialized) {
          _nameController.text = profile.fullName ?? '';
          _usernameController.text = profile.username;
          _bioController.text = profile.bio ?? '';
          _selectedInterests = List<String>.from(profile.interests);
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Chỉnh sửa hồ sơ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => _save(currentUserId, profile),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CupertinoActivityIndicator(),
                      )
                    : const Text(
                        'Lưu',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Stack for Cover and Avatar Picker
                SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      // Cover Banner
                      GestureDetector(
                        onTap: _pickCover,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                            image: _newCover != null
                                ? DecorationImage(
                                    image: kIsWeb
                                        ? NetworkImage(_newCover!.path)
                                        : FileImage(io.File(_newCover!.path)) as ImageProvider,
                                    fit: BoxFit.cover,
                                  )
                                : (profile.coverUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(profile.coverUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                          child: _newCover == null && profile.coverUrl == null
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          CupertinoIcons.photo,
                                          color: Colors.white70,
                                          size: 32,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Thay đổi ảnh bìa',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      
                      // Glassmorphic Edit Cover Pill Button
                      if (_newCover != null || profile.coverUrl != null)
                        Positioned(
                          bottom: 72,
                          right: 16,
                          child: GestureDetector(
                            onTap: _pickCover,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: Colors.black.withValues(alpha: 0.35),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.camera_fill, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Thay đổi ảnh bìa',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Avatar overlapping
                      Positioned(
                        top: 100,
                        left: 20,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).scaffoldBackgroundColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _newAvatar != null
                                  ? CircleAvatar(
                                      radius: 50,
                                      backgroundImage: kIsWeb
                                          ? NetworkImage(_newAvatar!.path)
                                          : FileImage(io.File(_newAvatar!.path)) as ImageProvider,
                                    )
                                  : AppAvatar(
                                      imageUrl: profile.avatarUrl,
                                      name: profile.displayName,
                                      radius: 50,
                                    ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: GestureDetector(
                                onTap: _pickAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).scaffoldBackgroundColor,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.camera_fill,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Form Fields
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Title
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.square_list_fill,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'THÔNG TIN CÁ NHÂN',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Card Box for Form
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTextField(
                                label: 'Họ và tên',
                                controller: _nameController,
                                validator: Validators.fullName,
                                prefixIcon: CupertinoIcons.person,
                              ),
                              const SizedBox(height: 18),
                              AppTextField(
                                label: 'Username',
                                controller: _usernameController,
                                validator: Validators.username,
                                prefixIcon: CupertinoIcons.at,
                              ),
                              const SizedBox(height: 18),
                              AppTextField(
                                 label: 'Bio',
                                 hint: 'Giới thiệu về bản thân...',
                                 controller: _bioController,
                                 maxLines: 4,
                                 maxLength: 150,
                                 prefixIcon: CupertinoIcons.info,
                                 keyboardType: TextInputType.multiline,
                                 textInputAction: TextInputAction.newline,
                               ),
                             ],
                           ),
                         ),
                       ),
                       
                       // ── Interests Wrap section ────────────────────
                       const SizedBox(height: 24),
                       Row(
                         children: [
                           Icon(
                             CupertinoIcons.heart_fill,
                             color: Theme.of(context).colorScheme.primary,
                             size: 18,
                           ),
                           const SizedBox(width: 8),
                           Text(
                             'SỞ THÍCH CỦA BẠN',
                             style: TextStyle(
                               color: Theme.of(context).colorScheme.primary,
                               fontSize: 13,
                               fontWeight: FontWeight.w800,
                               letterSpacing: 1.2,
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(height: 12),
                       Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chọn từ sở thích phổ biến:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  'Công nghệ', 'Thể thao', 'Âm nhạc', 'Nghệ thuật', 'Du lịch',
                                  'Ẩm thực', 'Thời trang', 'Gaming', 'Sách & Văn học', 'Phim ảnh',
                                  'Chụp ảnh', 'Kinh doanh', 'Sức khỏe', 'Làm vườn', 'Thú cưng'
                                ].map((interest) {
                                  final isSelected = _selectedInterests.contains(interest);
                                  return _ChoiceChipCustom(
                                    label: interest,
                                    isSelected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedInterests.add(interest);
                                        } else {
                                          _selectedInterests.remove(interest);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              AppTextField(
                                controller: _customInterestController,
                                hint: 'Thêm sở thích tự chọn khác...',
                                prefixIcon: CupertinoIcons.plus,
                                textInputAction: TextInputAction.done,
                                onEditingComplete: () {
                                  final text = _customInterestController.text.trim();
                                  if (text.isNotEmpty && !_selectedInterests.contains(text)) {
                                    setState(() {
                                      _selectedInterests.add(text);
                                      _customInterestController.clear();
                                    });
                                  }
                                },
                                suffix: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    final text = _customInterestController.text.trim();
                                    if (text.isNotEmpty && !_selectedInterests.contains(text)) {
                                      setState(() {
                                        _selectedInterests.add(text);
                                        _customInterestController.clear();
                                      });
                                    }
                                  },
                                  child: Icon(
                                    CupertinoIcons.plus_circle_fill,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              if (_selectedInterests.any((i) => ![
                                'Công nghệ', 'Thể thao', 'Âm nhạc', 'Nghệ thuật', 'Du lịch',
                                'Ẩm thực', 'Thời trang', 'Gaming', 'Sách & Văn học', 'Phim ảnh',
                                'Chụp ảnh', 'Kinh doanh', 'Sức khỏe', 'Làm vườn', 'Thú cưng'
                              ].contains(i))) ...[
                                const SizedBox(height: 18),
                                Text(
                                  'Sở thích đã thêm:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedInterests
                                      .where((i) => ![
                                            'Công nghệ', 'Thể thao', 'Âm nhạc', 'Nghệ thuật', 'Du lịch',
                                            'Ẩm thực', 'Thời trang', 'Gaming', 'Sách & Văn học', 'Phim ảnh',
                                            'Chụp ảnh', 'Kinh doanh', 'Sức khỏe', 'Làm vườn', 'Thú cưng'
                                          ].contains(i))
                                      .map((interest) {
                                    return _CustomTagCustom(
                                      label: interest,
                                      onDelete: () {
                                        setState(() {
                                          _selectedInterests.remove(interest);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                       const SizedBox(height: 20),
                     ],
                   ),
                 ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CupertinoActivityIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
    );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final compressed = await ImageUtils.compressImage(picked);
    setState(() => _newAvatar = compressed ?? picked);
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final compressed = await ImageUtils.compressImage(picked);
    setState(() => _newCover = compressed ?? picked);
  }

  Future<void> _save(String userId, dynamic profile) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(profileRepositoryProvider);
      String? newAvatarUrl;
      String? newCoverUrl;

      if (_newAvatar != null) {
        newAvatarUrl = await repo.uploadAvatar(userId, _newAvatar!);
      }
      if (_newCover != null) {
        newCoverUrl = await repo.uploadCover(userId, _newCover!);
      }

      await repo.updateProfile(
        userId: userId,
        fullName: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: newAvatarUrl,
        coverUrl: newCoverUrl,
        interests: _selectedInterests,
      );

      ref.invalidate(profileProvider(userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hồ sơ đã được cập nhật!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        debugPrint('Edit profile error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ChoiceChipCustom extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _ChoiceChipCustom({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isSelected
        ? theme.colorScheme.primary
        : (isDark ? Colors.white24 : Colors.black12);

    final textColor = isSelected
        ? theme.colorScheme.primary
        : (isDark ? Colors.white70 : Colors.black87);

    final bgColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : Colors.transparent;

    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CustomTagCustom extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _CustomTagCustom({
    required this.label,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = theme.colorScheme.primary.withValues(alpha: 0.3);
    final textColor = theme.colorScheme.primary;
    final bgColor = theme.colorScheme.primary.withValues(alpha: 0.05);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(
              CupertinoIcons.clear_circled_solid,
              size: 15,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
