import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../providers/chat_provider.dart';

// ── System Wallpaper Definitions ─────────────────────────────────────────────

class _SystemWallpaper {
  final String id;
  final String label;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const _SystemWallpaper({
    required this.id,
    required this.label,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });
}

const _kSystemWallpapers = [
  _SystemWallpaper(
    id: 'sys:aurora',
    label: 'Bắc cực quang',
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  ),
  _SystemWallpaper(
    id: 'sys:sunset',
    label: 'Hoàng hôn',
    colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  _SystemWallpaper(
    id: 'sys:ocean',
    label: 'Đại dương',
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  _SystemWallpaper(
    id: 'sys:lavender',
    label: 'Oải hương',
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
  ),
  _SystemWallpaper(
    id: 'sys:mint',
    label: 'Bạc hà',
    colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ),
  _SystemWallpaper(
    id: 'sys:rose',
    label: 'Hoa hồng',
    colors: [Color(0xFFFC5C7D), Color(0xFF6A3093)],
  ),
  _SystemWallpaper(
    id: 'sys:peach',
    label: 'Đào',
    colors: [Color(0xFFFFB347), Color(0xFFFF6B35)],
  ),
  _SystemWallpaper(
    id: 'sys:midnight',
    label: 'Đêm khuya',
    colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
  ),
  _SystemWallpaper(
    id: 'sys:sakura',
    label: 'Sakura',
    colors: [Color(0xFFFFE0EC), Color(0xFFFFC5D9), Color(0xFFFFABC8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  _SystemWallpaper(
    id: 'sys:forest',
    label: 'Rừng xanh',
    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF52B788)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  _SystemWallpaper(
    id: 'sys:galaxy',
    label: 'Thiên hà',
    colors: [Color(0xFF200122), Color(0xFF6F0000)],
  ),
  _SystemWallpaper(
    id: 'sys:sky',
    label: 'Bầu trời',
    colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
];

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
  final Set<String> _selectedPaths = {};
  late TabController _tabController;

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
    // +1 for the "Add new" button when not in select mode
    final itemCount = _selectMode ? historyList.length : historyList.length + 1;

    return Stack(
      children: [
        if (historyList.isEmpty && !_selectMode)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, size: 56, color: theme.hintColor.withValues(alpha: 0.35)),
                const SizedBox(height: 12),
                Text(
                  'Chưa có hình nền nào trong lịch sử',
                  style: TextStyle(color: theme.hintColor, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhấn + để chọn ảnh từ thư viện',
                  style: TextStyle(color: theme.hintColor.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          )
        else
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

  Widget _buildAddNewButton(Color cardBgColor, ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (picked != null) {
          await ref
              .read(chatWallpaperProvider.notifier)
              .setWallpaper(widget.conversationId, picked.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật hình nền cuộc trò chuyện'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15), width: 1),
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
              child: Icon(CupertinoIcons.plus, size: 22, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm mới',
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
          _applyWallpaper(path);
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
            _applyWallpaper(wp.id);
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
                  // Gradient preview
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: wp.colors,
                        begin: wp.begin,
                        end: wp.end,
                      ),
                    ),
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: wp.colors, begin: wp.begin, end: wp.end),
          ),
        );
      }
      return Container(color: Colors.grey);
    }

    if (path.startsWith('http') || path.startsWith('blob')) {
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

  void _applyWallpaper(String path) {
    ref.read(chatWallpaperProvider.notifier).setWallpaper(widget.conversationId, path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật hình nền cuộc trò chuyện'),
        duration: Duration(seconds: 1),
      ),
    );
    Navigator.pop(context);
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
