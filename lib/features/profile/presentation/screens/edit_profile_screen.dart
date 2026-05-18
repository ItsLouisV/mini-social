import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';


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

  bool _isLoading = false;
  XFile? _newAvatar;
  XFile? _newCover;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
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
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Chỉnh sửa hồ sơ'),
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark),
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
                        child: CupertinoActivityIndicator())
                    : const Text('Lưu',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar picker
                  Center(
                    child: Stack(
                      children: [
                        _newAvatar != null
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
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: const Icon(CupertinoIcons.camera_fill,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _pickCover,
                      child: Text(_newCover != null
                          ? '✓ Ảnh bìa đã chọn'
                          : 'Thay đổi ảnh bìa'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  AppTextField(
                    label: 'Họ và tên',
                    controller: _nameController,
                    validator: Validators.fullName,
                    prefixIcon: CupertinoIcons.person,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Username',
                    controller: _usernameController,
                    validator: Validators.username,
                    prefixIcon: CupertinoIcons.at,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Bio',
                    hint: 'Giới thiệu về bản thân...',
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 150,
                    prefixIcon: CupertinoIcons.info,
                  ),
                ],
              ),
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
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
