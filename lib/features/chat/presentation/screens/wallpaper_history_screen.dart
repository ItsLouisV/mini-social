import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

// ── System Wallpaper Definitions ─────────────────────────────────────────────

class _SystemWallpaper {
  final String id;
  final String label;
  final String assetPath;

  const _SystemWallpaper({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

final _kSystemWallpapers = List.generate(28, (index) {
  final num = index + 1;
  return _SystemWallpaper(
    id: 'sys:wp_$num',
    label: 'Hình nền $num',
    assetPath: 'assets/images/wallpapers/wallpaper$num.jpg',
  );
});

bool _isSystemWallpaper(String path) => path.startsWith('sys:');

_SystemWallpaper? _findSystemWallpaper(String id) {
  try {
    return _kSystemWallpapers.firstWhere((w) => w.id == id);
  } catch (_) {
    return null;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WallpaperHistoryScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const WallpaperHistoryScreen({super.key, required this.conversationId});

  @override
  ConsumerState<WallpaperHistoryScreen> createState() => _WallpaperHistoryScreenState();
}

class _WallpaperHistoryScreenState extends ConsumerState<WallpaperHistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _selectMode = false;
  bool _uploading = false;
  final Set<String> _selectedPaths = {};
  late TabController _tabController;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final historyMap = ref.watch(chatWallpaperHistoryProvider);
    final rawHistory = historyMap[widget.conversationId] ?? [];
    final activeWallpaper = ref.watch(chatWallpaperProvider)[widget.conversationId] ?? '';

    // Sort: active wallpaper first, then the rest
    final historyList = List<String>.from(rawHistory);
    if (activeWallpaper.isNotEmpty && historyList.contains(activeWallpaper)) {
      historyList.remove(activeWallpaper);
      historyList.insert(0, activeWallpaper);
    }

    final bgColor = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF6F8FA);
    final cardBgColor = isDark ? const Color(0xFF1E1E2F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Hình nền trò chuyện',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            _selectMode ? CupertinoIcons.xmark : CupertinoIcons.left_chevron,
            color: theme.colorScheme.primary,
          ),
          onPressed: () {
            if (_selectMode) {
              setState(() {
                _selectMode = false;
                _selectedPaths.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_selectMode)
            PopupMenuButton<String>(
              icon: Icon(CupertinoIcons.ellipsis_vertical, color: theme.colorScheme.primary),
              onSelected: (val) {
                if (val == 'select') {
                  setState(() {
                    _selectMode = true;
                    _selectedPaths.clear();
                  });
                } else if (val == 'clear_all') {
                  _confirmClearAll(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'select',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.checkmark_circle, size: 18),
                      SizedBox(width: 8),
                      Text('Chọn'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.trash, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: _selectMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: theme.scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: theme.colorScheme.primary,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.hintColor,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: 'Đã dùng (${historyList.length})'),
                      const Tab(text: 'Hệ thống'),
                    ],
                  ),
                ),
              ),
      ),
      body: _selectMode
          ? _buildHistoryGrid(historyList, activeWallpaper, cardBgColor, theme)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryGrid(historyList, activeWallpaper, cardBgColor, theme),
                _buildSystemWallpapersGrid(activeWallpaper, cardBgColor, theme),
              ],
            ),
    );
  }

  // ── History Tab ─────────────────────────────────────────────────────────────

  Widget _buildHistoryGrid(
    List<String> historyList,
    String activeWallpaper,
    Color cardBgColor,
    ThemeData theme,
  ) {
    // +1 for the "Add new" button when not in select mode — always shown
    final itemCount = _selectMode ? historyList.length : historyList.length + 1;

    return Stack(
      children: [
        // Grid is always rendered (so the + button is always visible)
        GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, _selectMode ? 80 : 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.65,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // "Add new" button at index 0 (non-select mode only)
            if (!_selectMode && index == 0) {
              return _buildAddNewButton(cardBgColor, theme);
            }

            final path = historyList[_selectMode ? index : index - 1];
            final isSelected = _selectedPaths.contains(path);
            final isActive = activeWallpaper == path;

              return _buildHistoryItem(
                path: path,
                isActive: isActive,
                isSelected: isSelected,
                cardBgColor: cardBgColor,
                theme: theme,
              );
            },
          ),
        if (_selectMode) _buildSelectModeBottomBar(theme),
      ],
    );
  }

  // ── Upload to Supabase Storage ─────────────────────────────────────────────

  Future<String?> _uploadWallpaper(XFile picked) async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id ?? 'anonymous';
      final ext = picked.name.split('.').last.toLowerCase();
      final fileName = '$uid/${_uuid.v4()}.$ext';
      final bucket = SupabaseConstants.wallpapersBucket;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        await client.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: false,
          ),
        );
      } else {
        await client.storage.from(bucket).upload(
          fileName,
          io.File(picked.path),
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: false,
          ),
        );
      }

      return client.storage.from(bucket).getPublicUrl(fileName);
    } catch (e) {
      return null;
    }
  }

  Widget _buildAddNewButton(Color cardBgColor, ThemeData theme) {
    return GestureDetector(
      onTap: _uploading
          ? null
          : () async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (picked == null || !mounted) return;

              setState(() => _uploading = true);
              try {
                // Upload to Supabase Storage → get persistent public URL
                final url = await _uploadWallpaper(picked);
                if (!mounted) return;

                if (url == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lỗi tải ảnh lên. Vui lòng thử lại.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                _showPreviewAndApply(url);
              } finally {
                if (mounted) setState(() => _uploading = false);
              }
            },
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _uploading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : Icon(CupertinoIcons.plus,
                      size: 22, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              _uploading ? 'Đang tải...' : 'Thêm mới',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Từ thư viện',
              style: TextStyle(color: theme.hintColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required String path,
    required bool isActive,
    required bool isSelected,
    required Color cardBgColor,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: () {
        if (_selectMode) {
          setState(() {
            if (isSelected) {
              _selectedPaths.remove(path);
            } else {
              _selectedPaths.add(path);
            }
          });
        } else {
          HapticFeedback.lightImpact();
          _showPreviewAndApply(path);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary
                : (isSelected ? Colors.redAccent : Colors.transparent),
            width: isActive ? 3 : 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildWallpaperPreview(path),
              // Active badge
              if (isActive)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.9),
                          theme.colorScheme.primary.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.checkmark_alt_circle_fill,
                            size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Đang dùng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Select mode checkbox
              if (_selectMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.redAccent : Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(CupertinoIcons.checkmark, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── System Wallpapers Tab ───────────────────────────────────────────────────

  Widget _buildSystemWallpapersGrid(
    String activeWallpaper,
    Color cardBgColor,
    ThemeData theme,
  ) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.65,
      ),
      itemCount: _kSystemWallpapers.length,
      itemBuilder: (context, index) {
        final wp = _kSystemWallpapers[index];
        final isActive = activeWallpaper == wp.id;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showPreviewAndApply(wp.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? theme.colorScheme.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image preview
                  Image.asset(
                    wp.assetPath,
                    fit: BoxFit.cover,
                  ),
                  // Label at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Text(
                        wp.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Active badge
                  if (isActive)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.checkmark_alt_circle_fill,
                                size: 10, color: Colors.white),
                            SizedBox(width: 3),
                            Text(
                              'Đang dùng',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Select mode bottom bar ──────────────────────────────────────────────────

  Widget _buildSelectModeBottomBar(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectMode = false;
                    _selectedPaths.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Xóa (${_selectedPaths.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildWallpaperPreview(String path) {
    if (_isSystemWallpaper(path)) {
      final wp = _findSystemWallpaper(path);
      if (wp != null) {
        return Image.asset(
          wp.assetPath,
          fit: BoxFit.cover,
        );
      }
      return Container(color: Colors.grey);
    }

    if (path.startsWith('blob:')) {
      return const Center(child: Icon(CupertinoIcons.photo, size: 24));
    } else if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 24),
      );
    } else if (kIsWeb) {
      return const Center(child: Icon(CupertinoIcons.photo, size: 24));
    } else {
      return Image.file(
        io.File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 24),
      );
    }
  }

  void _showPreviewAndApply(String path) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _WallpaperPreviewScreen(
          path: path,
          buildPreviewWidget: _buildWallpaperPreview(path),
        ),
      ),
    );

    if (result != null && result['apply'] == true && mounted) {
      final applyToBoth = result['applyToBoth'] as bool? ?? false;
      
      String? otherUserId;
      if (applyToBoth) {
        final conversations = ref.read(conversationsProvider).valueOrNull ?? [];
        final matches = conversations.where((c) => c.id == widget.conversationId);
        final conversation = matches.isNotEmpty ? matches.first : null;
        final currentUserId = ref.read(currentUserIdProvider) ?? '';
        if (conversation != null) {
          otherUserId = conversation.getOtherUserId(currentUserId);
        }
      }

      await ref
          .read(chatWallpaperProvider.notifier)
          .setWallpaper(widget.conversationId, path, otherUserId: otherUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật hình nền cuộc trò chuyện'),
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _deleteSelected() {
    HapticFeedback.mediumImpact();
    for (final path in _selectedPaths) {
      ref
          .read(chatWallpaperHistoryProvider.notifier)
          .removeWallpaperFromHistory(widget.conversationId, path);
      final active = ref.read(chatWallpaperProvider)[widget.conversationId] ?? '';
      if (active == path) {
        ref.read(chatWallpaperProvider.notifier).setWallpaper(widget.conversationId, '');
      }
    }
    setState(() {
      _selectMode = false;
      _selectedPaths.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa hình nền được chọn khỏi lịch sử'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Xóa toàn bộ hình nền cũ?'),
        content: const Text(
            'Thao tác này sẽ xóa tất cả hình nền trong lịch sử đã sử dụng cho cuộc trò chuyện này. Bạn có chắc chắn không?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Huỷ'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await ref
                  .read(chatWallpaperHistoryProvider.notifier)
                  .clearHistory(widget.conversationId);
              await ref
                  .read(chatWallpaperProvider.notifier)
                  .setWallpaper(widget.conversationId, '');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa sạch lịch sử hình nền'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
  }
}

// ── Wallpaper Preview Screen with Simulated Chat ─────────────────────────────

class _WallpaperPreviewScreen extends StatefulWidget {
  final String path;
  final Widget buildPreviewWidget;

  const _WallpaperPreviewScreen({
    required this.path,
    required this.buildPreviewWidget,
  });

  @override
  State<_WallpaperPreviewScreen> createState() => _WallpaperPreviewScreenState();
}

class _WallpaperPreviewScreenState extends State<_WallpaperPreviewScreen> {
  bool _applyToBoth = false;
  bool _xHoveredOrPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background wallpaper preview
        Positioned.fill(child: widget.buildPreviewWidget),
        // Dark screen overlay to read messages easily
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.1),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Xem trước hình nền',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: _buildSimulatedChat(context),
              ),
              _buildBottomPanel(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatedChat(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myBgColor = isDark ? const Color(0xFF1B3D6D) : const Color(0xFFD0ECFC);
    final theirBgColor = isDark ? const Color(0xFF2E2E3E) : const Color(0xFFEBEBEB);
    final myTextColor = isDark ? Colors.white : Colors.black87;
    final theirTextColor = isDark ? Colors.white70 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Hôm nay',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: myBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                'Chào bạn, hình nền này trông thế nào?',
                style: TextStyle(color: myTextColor, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'U',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theirBgColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Đẹp quá! Nhìn rất dễ chịu và hợp mắt.',
                      style: TextStyle(color: theirTextColor, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: myBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                'Ok, mình sẽ chọn hình này nhé! 😊',
                style: TextStyle(color: myTextColor, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Theme(
                data: ThemeData(
                  unselectedWidgetColor: Colors.white,
                ),
                child: Checkbox(
                  value: _applyToBoth,
                  activeColor: const Color(0xFF007AFF),
                  checkColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  onChanged: (val) {
                    setState(() {
                      _applyToBoth = val ?? false;
                    });
                  },
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Áp dụng cho cả hai bên',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Cả bạn và người kia đều thấy hình nền này trong chat',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Circular X/Cancel button on the left
              MouseRegion(
                onEnter: (_) => setState(() => _xHoveredOrPressed = true),
                onExit: (_) => setState(() => _xHoveredOrPressed = false),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _xHoveredOrPressed = true),
                  onTapUp: (_) => setState(() => _xHoveredOrPressed = false),
                  onTapCancel: () => setState(() => _xHoveredOrPressed = false),
                  onTap: () => Navigator.pop(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _xHoveredOrPressed
                          ? const Color(0xFFFF2D55) // Apple Music Red
                          : Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _xHoveredOrPressed ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 24),
                  ),
                ),
              ),
              // Circular Checkmark/Apply button on the right
              GestureDetector(
                onTap: () {
                  Navigator.pop(context, {
                    'apply': true,
                    'applyToBoth': _applyToBoth,
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.checkmark, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
