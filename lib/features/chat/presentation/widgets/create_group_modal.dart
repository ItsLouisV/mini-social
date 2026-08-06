import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../profile/domain/profile_model.dart';
import '../../../social/providers/follow_list_provider.dart';
import '../../providers/chat_provider.dart';

class CreateGroupModal extends ConsumerStatefulWidget {
  const CreateGroupModal({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateGroupModal(),
    );
  }

  @override
  ConsumerState<CreateGroupModal> createState() => _CreateGroupModalState();
}

class _CreateGroupModalState extends ConsumerState<CreateGroupModal> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  XFile? _groupAvatar;
  final Set<ProfileModel> _selectedFriends = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final compressed = await ImageUtils.compressImage(picked);
    setState(() => _groupAvatar = compressed ?? picked);
  }

  Future<void> _handleCreateGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ToastService.showWarning(context, 'Vui lòng nhập tên nhóm');
      return;
    }
    if (_selectedFriends.length < 2) {
      ToastService.showWarning(context, 'Nhóm phải có ít nhất 3 thành viên (bao gồm bạn)');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final memberIds = _selectedFriends.map((f) => f.id).toList();

      final newConv = await repo.createGroupConversation(
        name: name,
        avatar: _groupAvatar,
        memberIds: memberIds,
      );

      ref.invalidate(conversationsProvider);

      if (mounted) {
        Navigator.pop(context, newConv.id);
        ToastService.showSuccess(context, 'Đã tạo nhóm "$name" thành công!');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [CreateGroupModal Error]: $e\n$stackTrace');
      if (mounted) {
        ToastService.showError(context, 'Lỗi tạo nhóm: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);
    final friendsAsync = currentUserId != null
        ? ref.watch(friendsListProvider(currentUserId))
        : const AsyncValue<List<ProfileModel>>.data([]);

    final canCreate = _nameController.text.trim().isNotEmpty && _selectedFriends.length >= 2;

    final cardBgColor = isDark
        ? const Color(0xFF252536)
        : const Color(0xFFF4F6FB);

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181824) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── 1. Top Navigation Bar ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  // Cancel Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Hủy',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Header Title
                  const Expanded(
                    child: Text(
                      'Tạo nhóm mới',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Create Action Button (Pill Gradient)
                  _isCreating
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CupertinoActivityIndicator(),
                        )
                      : AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: canCreate
                                ? const LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: canCreate
                                ? null
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.grey.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: canCreate
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF007AFF).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: canCreate ? _handleCreateGroup : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                child: Text(
                                  'Tạo',
                                  style: TextStyle(
                                    color: canCreate
                                        ? Colors.white
                                        : theme.hintColor.withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.2)),

            // ── 2. Hero Section: Group Avatar & Name Input Card ───────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar Picker Button with Gradient Border Ring
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            padding: const EdgeInsets.all(3.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF007AFF), Color(0xFFA259FF), Color(0xFFFF62A5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1F1F2C) : Colors.white,
                                image: _groupAvatar != null
                                    ? DecorationImage(
                                        image: kIsWeb
                                            ? NetworkImage(_groupAvatar!.path)
                                            : FileImage(io.File(_groupAvatar!.path))
                                                as ImageProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _groupAvatar == null
                                  ? const Icon(
                                      CupertinoIcons.person_3_fill,
                                      color: AppColors.primary,
                                      size: 36,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cardBgColor,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF007AFF).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.camera_fill,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sleek CupertinoTextField for Group Name with explicit 20px pill corner rounding
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CupertinoTextField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        maxLength: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        placeholder: 'Đặt tên nhóm trò chuyện...',
                        placeholderStyle: TextStyle(
                          color: theme.hintColor.withValues(alpha: 0.6),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1C2A)
                              : const Color(0xFFEAEEF6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _nameController.text.isNotEmpty
                                ? AppColors.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1)),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                  alpha: _nameController.text.isNotEmpty ? 0.18 : 0.0),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.person_3_fill,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                        ),
                        suffix: _nameController.text.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    _nameController.clear();
                                    setState(() {});
                                  },
                                  child: Icon(
                                    CupertinoIcons.xmark_circle_fill,
                                    color: theme.hintColor.withValues(alpha: 0.6),
                                    size: 18,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tên nhóm giúp các thành viên dễ dàng nhận diện hội thoại',
                      style: TextStyle(
                        color: theme.hintColor.withValues(alpha: 0.7),
                        fontSize: 11.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Selected Members Horizontal Scroll Carousel ────────
            if (_selectedFriends.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'ĐÃ CHỌN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _selectedFriends.length >= 2
                            ? '${_selectedFriends.length} người (Đủ điều kiện)'
                            : '${_selectedFriends.length}/2 bạn bè (Tối thiểu 3 người bao gồm bạn)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedFriends.length >= 2 ? AppColors.primary : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedFriends.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final friend = _selectedFriends.elementAt(index);
                    return Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 1.8,
                                ),
                              ),
                              child: AppAvatar(
                                imageUrl: friend.avatarUrl,
                                name: friend.displayName,
                                radius: 22,
                              ),
                            ),
                            Positioned(
                              right: -2,
                              top: -2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFriends.remove(friend);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF181824) : Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.xmark,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 58,
                          child: Text(
                            friend.displayName.split(' ').last,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.15)),
            ],

            // ── 4. Friends List Header & Search Input ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Tìm kiếm bạn bè...',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                placeholderStyle: TextStyle(color: theme.hintColor),
                backgroundColor: isDark
                    ? const Color(0xFF252536)
                    : const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(14),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // ── 5. Friends Multi-Select List ──────────────────────────
            Expanded(
              child: friendsAsync.when(
                data: (friends) {
                  final filtered = friends.where((f) {
                    final name = f.displayName.toLowerCase();
                    final username = f.username.toLowerCase();
                    return name.contains(_searchQuery) || username.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'Chưa có người bạn nào' : 'Không tìm thấy bạn bè',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 0.5,
                      indent: 72,
                      color: theme.dividerColor.withValues(alpha: 0.15),
                    ),
                    itemBuilder: (context, index) {
                      final friend = filtered[index];
                      final isSelected = _selectedFriends.contains(friend);

                      return ListTile(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedFriends.remove(friend);
                            } else {
                              _selectedFriends.add(friend);
                            }
                          });
                        },
                        leading: AppAvatar(
                          imageUrl: friend.avatarUrl,
                          name: friend.displayName,
                          radius: 22,
                        ),
                        title: Text(
                          friend.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '@${friend.username}',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 13,
                          ),
                        ),
                        trailing: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : theme.hintColor.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  CupertinoIcons.checkmark,
                                  color: Colors.white,
                                  size: 15,
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
