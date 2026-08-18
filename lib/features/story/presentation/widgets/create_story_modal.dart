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
  final FocusNode _captionFocusNode = FocusNode();

  XFile? _selectedImage;
  MusicTrackModel? _selectedMusicTrack;
  String _selectedBgColor = '#1C1C1E';
  bool _isPublishing = false;

  // Text Styling State
  double _fontSize = 28.0;
  Color _selectedTextColor = Colors.white;
  int _selectedTextStyleIndex = 0; // 0 = None, 1 = Dark Box, 2 = White Box, 3 = Neon Glass
  int _selectedFontIndex = 0;
  bool _isEditingText = false;
  String _activeActionTab = 'color'; // 'font', 'color', 'textBg', 'canvasBg'

  // Text Dragging State
  Offset? _textOffset;
  Offset _dragStartTouchPosition = Offset.zero;
  Offset _dragStartTextOffset = Offset.zero;
  bool _isDraggingText = false;
  bool _isOverTrash = false;

  final List<Map<String, String>> _colorPalettes = [
    {'name': 'Đêm thẫm', 'color': '#1C1C1E'},
    {'name': 'Tím Vô Cực', 'color': '#2E1065'},
    {'name': 'Tím Neon', 'color': '#3B0764'},
    {'name': 'Xanh Đêm', 'color': '#0F172A'},
    {'name': 'Xanh Biển', 'color': '#0369A1'},
    {'name': 'Xanh Ngọc', 'color': '#0D9488'},
    {'name': 'Ngọc Lục', 'color': '#065F46'},
    {'name': 'Lục Đen', 'color': '#022C22'},
    {'name': 'Hoàng Hôn', 'color': '#991B1B'},
    {'name': 'Đỏ Rượu', 'color': '#4C0519'},
    {'name': 'Ánh Hồng', 'color': '#831843'},
    {'name': 'Hồng Đô', 'color': '#701A75'},
    {'name': 'Cam Đất', 'color': '#7C2D12'},
    {'name': 'Nâu Cà Phê', 'color': '#451A03'},
    {'name': 'Xám Khói', 'color': '#374151'},
    {'name': 'Vàng Kim', 'color': '#713F12'},
    {'name': 'Xanh Chàm', 'color': '#1E1B4B'},
    {'name': 'Xanh Mint', 'color': '#064E3B'},
    {'name': 'Đỏ Neon', 'color': '#881337'},
    {'name': 'Đen Tuyệt Đối', 'color': '#000000'},
  ];

  final List<Color> _textColors = [
    Colors.white,
    const Color(0xFFFACC15), // Gold Yellow
    const Color(0xFFFF5722), // Bright Coral
    const Color(0xFFEC4899), // Hot Pink
    const Color(0xFFF43F5E), // Rose Red
    const Color(0xFFE11D48), // Deep Crimson
    const Color(0xFFA855F7), // Violet Purple
    const Color(0xFF6366F1), // Indigo Blue
    const Color(0xFF3B82F6), // Electric Blue
    const Color(0xFF00E5FF), // Cyan Neon
    const Color(0xFF38BDF8), // Sky Blue
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF34D399), // Mint Green
    const Color(0xFF4ADE80), // Lime Green
    const Color(0xFFA3E635), // Lemon Lime
    const Color(0xFF10B981), // Emerald
    const Color(0xFFFB923C), // Bright Orange
    const Color(0xFFFDBA74), // Pastel Peach
    const Color(0xFFFEF3C7), // Soft Cream
    const Color(0xFFC084FC), // Lavender
    const Color(0xFFA5F3FC), // Light Aqua
    const Color(0xFFD97706), // Warm Amber
    const Color(0xFF94A3B8), // Slate Grey
    const Color(0xFF64748B), // Medium Grey
    Colors.black,
  ];

  final List<Map<String, dynamic>> _fontStyles = [
    {
      'name': 'Arial',
      'fontFamily': 'Arial',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Times',
      'fontFamily': 'Times New Roman',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Courier',
      'fontFamily': 'Courier New',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Georgia',
      'fontFamily': 'Georgia',
      'fontWeight': FontWeight.w600,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Impact',
      'fontFamily': 'Impact',
      'fontWeight': FontWeight.w900,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Comic Sans',
      'fontFamily': 'Comic Sans MS',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Trebuchet',
      'fontFamily': 'Trebuchet MS',
      'fontWeight': FontWeight.w700,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Cổ điển',
      'fontFamily': 'Serif',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Đánh máy',
      'fontFamily': 'Monospace',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Viết tay',
      'fontFamily': 'Cursive',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.normal,
    },
    {
      'name': 'Times Nghiêng',
      'fontFamily': 'Times New Roman',
      'fontWeight': FontWeight.bold,
      'fontStyle': FontStyle.italic,
    },
  ];

  final List<Map<String, dynamic>> _textBgStyles = [
    {'name': 'Trong suốt', 'icon': CupertinoIcons.slash_circle},
    {'name': 'Hộp tối', 'icon': CupertinoIcons.square_fill},
    {'name': 'Hộp sáng', 'icon': CupertinoIcons.square},
    {'name': 'Viền viền', 'icon': CupertinoIcons.app_badge_fill},
  ];

  @override
  void initState() {
    super.initState();
    _captionFocusNode.addListener(() {
      if (_captionFocusNode.hasFocus && !_isEditingText) {
        setState(() => _isEditingText = true);
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  void _finishEditingText() {
    _captionFocusNode.unfocus();
    setState(() => _isEditingText = false);
  }

  void _updateFontSizeFromY(double localY, double totalHeight) {
    if (totalHeight <= 0) return;
    final fraction = (1.0 - (localY / totalHeight)).clamp(0.0, 1.0);
    final newSize = (12.0 + fraction * (72.0 - 12.0)).clamp(12.0, 72.0);
    setState(() => _fontSize = newSize);
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

  BoxDecoration? _getTextContainerDecoration() {
    switch (_selectedTextStyleIndex) {
      case 1:
        return BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(12),
        );
      case 2:
        return BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        );
      case 3:
        return BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        );
      default:
        return null;
    }
  }

  Color _getEffectiveTextColor() {
    if (_selectedTextStyleIndex == 2 && _selectedTextColor == Colors.white) {
      return Colors.black;
    }
    return _selectedTextColor;
  }

  Future<void> _publishStory() async {
    final caption = _captionController.text.trim();
    if (_selectedImage == null && caption.isEmpty && _selectedMusicTrack == null) {
      ToastService.showWarning(context, 'Hãy thêm hình ảnh, viết gì đó hoặc chọn bài hát');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final metadata = {
        'font_size': _fontSize,
        'text_color': '#${_selectedTextColor.toARGB32().toRadixString(16)}',
        'font_index': _selectedFontIndex,
        'text_style_index': _selectedTextStyleIndex,
        if (_textOffset != null) 'offset_x': _textOffset!.dx,
        if (_textOffset != null) 'offset_y': _textOffset!.dy,
      };

      await ref.read(storyRepositoryProvider).createStory(
            imageFile: _selectedImage,
            caption: caption.isNotEmpty ? caption : null,
            musicTrack: _selectedMusicTrack,
            backgroundColor: _selectedBgColor,
            metadata: metadata,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final fontConfig = _fontStyles[_selectedFontIndex];
    final effectiveTextColor = _getEffectiveTextColor();
    final hasText = _captionController.text.isNotEmpty;

    // Default text position center
    final textPos = _textOffset ?? Offset(16, screenHeight * 0.35);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: screenHeight * 0.98,
        color: bgColor,
        child: Stack(
          children: [
            // 1. FULLSCREEN CANVAS BACKGROUND
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

            // Subtle dark overlay over image
            if (_selectedImage != null)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

            // 2. TEXT INPUT / DRAGGABLE CANVAS ELEMENT (Tight Wrapping with IntrinsicWidth)
            if (!_isEditingText) ...[
              // Canvas Preview / Draggable Mode
              Positioned(
                left: textPos.dx,
                top: textPos.dy,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isEditingText = true);
                    _captionFocusNode.requestFocus();
                  },
                  onPanStart: (details) {
                    _dragStartTouchPosition = details.globalPosition;
                    _dragStartTextOffset = _textOffset ?? Offset(16, screenHeight * 0.35);
                    setState(() => _isDraggingText = true);
                  },
                  onPanUpdate: (details) {
                    final delta = details.globalPosition - _dragStartTouchPosition;
                    final newOffset = _dragStartTextOffset + delta;
                    final isOverTrash = (newOffset.dy > screenHeight - 190) &&
                        ((newOffset.dx + (screenWidth * 0.25) - screenWidth / 2).abs() < 130);
                    setState(() {
                      _textOffset = newOffset;
                      _isOverTrash = isOverTrash;
                    });
                  },
                  onPanEnd: (_) {
                    if (_isOverTrash) {
                      _captionController.clear();
                      setState(() {
                        _textOffset = null;
                        _isDraggingText = false;
                        _isOverTrash = false;
                      });
                      ToastService.showSuccess(context, 'Đã xóa chữ');
                    } else {
                      setState(() {
                        _isDraggingText = false;
                        _isOverTrash = false;
                      });
                    }
                  },
                  child: IntrinsicWidth(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: screenWidth - 32),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: _getTextContainerDecoration(),
                      child: Text(
                        hasText ? _captionController.text : 'Chạm để viết văn bản...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: hasText ? effectiveTextColor : effectiveTextColor.withValues(alpha: 0.65),
                          fontSize: _fontSize,
                          fontWeight: fontConfig['fontWeight'] as FontWeight,
                          fontStyle: fontConfig['fontStyle'] as FontStyle,
                          fontFamily: fontConfig['fontFamily'] as String?,
                          shadows: _selectedTextStyleIndex == 0
                              ? const [Shadow(blurRadius: 10, color: Colors.black87)]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Active Editing Mode (Tight wrapping centered input)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: IntrinsicWidth(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: screenWidth - 48, minWidth: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: _getTextContainerDecoration(),
                      child: TextField(
                        controller: _captionController,
                        focusNode: _captionFocusNode,
                        textAlign: TextAlign.center,
                        maxLines: null,
                        autofocus: true,
                        style: TextStyle(
                          color: effectiveTextColor,
                          fontSize: _fontSize,
                          fontWeight: fontConfig['fontWeight'] as FontWeight,
                          fontStyle: fontConfig['fontStyle'] as FontStyle,
                          fontFamily: fontConfig['fontFamily'] as String?,
                          shadows: _selectedTextStyleIndex == 0
                              ? const [Shadow(blurRadius: 10, color: Colors.black87)]
                              : null,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập nội dung...',
                          hintStyle: TextStyle(
                            color: effectiveTextColor.withValues(alpha: 0.65),
                            fontSize: _fontSize,
                            fontWeight: fontConfig['fontWeight'] as FontWeight,
                            fontStyle: fontConfig['fontStyle'] as FontStyle,
                            fontFamily: fontConfig['fontFamily'] as String?,
                            shadows: _selectedTextStyleIndex == 0
                                ? const [Shadow(blurRadius: 8, color: Colors.black87)]
                                : null,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // 3. LEFT VERTICAL REALTIME GESTURE SLIDER (100% Zero-Lag Touch Tracking)
            if (_isEditingText)
              Positioned(
                left: 14,
                top: 120,
                bottom: MediaQuery.of(context).viewInsets.bottom + 110,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final sliderHeight = constraints.maxHeight;
                    final progressFraction = ((_fontSize - 12.0) / (72.0 - 12.0)).clamp(0.05, 1.0);

                    return GestureDetector(
                      onVerticalDragStart: (details) =>
                          _updateFontSizeFromY(details.localPosition.dy, sliderHeight),
                      onVerticalDragUpdate: (details) =>
                          _updateFontSizeFromY(details.localPosition.dy, sliderHeight),
                      child: Container(
                        width: 24,
                        height: sliderHeight,
                        color: Colors.transparent,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // Track bar (thin 4px line)
                            Container(
                              width: 4,
                              height: sliderHeight,
                              decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Active fill track
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 4,
                                height: sliderHeight * progressFraction,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            // Sleek 16px white thumb indicator circle
                            Positioned(
                              bottom: (sliderHeight * progressFraction - 8)
                                  .clamp(0.0, sliderHeight - 16),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 4. FLOATING TOP HEADER BAR
            if (!_isDraggingText)
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
                        if (_selectedImage != null && !_isEditingText)
                          IconButton(
                            onPressed: () => setState(() => _selectedImage = null),
                            icon: const Icon(CupertinoIcons.trash, color: Colors.white70, size: 20),
                          ),
                        ElevatedButton(
                          onPressed: _isEditingText
                              ? _finishEditingText
                              : (_isPublishing ? null : _publishStory),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isEditingText ? const Color(0xFF38BDF8) : AppColors.primary,
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
                              : Text(
                                  _isEditingText ? 'Xong' : 'Đăng tin',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 5. FLOATING MUSIC CHIP (If Music Selected)
            if (_selectedMusicTrack != null && !_isDraggingText)
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

            // 6. ACTION TOOLBAR ABOVE KEYBOARD / BOTTOM (When Editing Text)
            if (_isEditingText)
              Positioned(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SUB-ACTION OPTION PICKER (Floating freely above main action bar)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildSubActionOptions(),
                    ),
                    const SizedBox(height: 10),

                    // PARENT ACTION BAR (Rounded Rectangle Container)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Tab 1: Font
                          _buildActionBarTab(
                            tabKey: 'font',
                            icon: CupertinoIcons.textformat,
                            label: 'Font',
                          ),
                          // Tab 2: Color
                          _buildActionBarTab(
                            tabKey: 'color',
                            icon: CupertinoIcons.color_filter,
                            label: 'Màu chữ',
                          ),
                          // Tab 3: Text Background
                          _buildActionBarTab(
                            tabKey: 'textBg',
                            icon: CupertinoIcons.square_fill_on_square_fill,
                            label: 'Khung',
                          ),
                          // Tab 4: Canvas Background
                          _buildActionBarTab(
                            tabKey: 'canvasBg',
                            icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                            label: 'Nền tin',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 7. FLOATING BOTTOM ACTION TOOLBAR (When Previewing Canvas)
            if (!_isEditingText && !_isDraggingText)
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _isEditingText = true);
                          _captionFocusNode.requestFocus();
                        },
                        icon: const Icon(CupertinoIcons.textformat, color: Colors.white, size: 18),
                        label: const Text('Viết chữ', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          backgroundColor: Colors.black45,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
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
                          _selectedMusicTrack != null ? 'Đổi nhạc' : 'Nhạc',
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
                ),
              ),

            // 8. TRASH BIN ICON AT BOTTOM CENTER (During Dragging Text)
            if (_isDraggingText)
              Positioned(
                bottom: 36,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(_isOverTrash ? 18 : 14),
                    decoration: BoxDecoration(
                      color: _isOverTrash ? Colors.red.withValues(alpha: 0.95) : Colors.black87,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isOverTrash ? Colors.white : Colors.white38,
                        width: 2,
                      ),
                      boxShadow: [
                        if (_isOverTrash)
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.6),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.trash,
                      color: Colors.white,
                      size: _isOverTrash ? 30 : 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBarTab({
    required String tabKey,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeActionTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeActionTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubActionOptions() {
    switch (_activeActionTab) {
      case 'font':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _fontStyles.asMap().entries.map((entry) {
              final idx = entry.key;
              final font = entry.value;
              final isSelected = _selectedFontIndex == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedFontIndex = idx),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    font['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 12,
                      fontWeight: font['fontWeight'] as FontWeight,
                      fontStyle: font['fontStyle'] as FontStyle,
                      fontFamily: font['fontFamily'] as String?,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

      case 'color':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _textColors.map((color) {
              final isSelected = _selectedTextColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedTextColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white30,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

      case 'textBg':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _textBgStyles.asMap().entries.map((entry) {
              final idx = entry.key;
              final style = entry.value;
              final isSelected = _selectedTextStyleIndex == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedTextStyleIndex = idx),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(style['icon'] as IconData, size: 14, color: isSelected ? Colors.black : Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        style['name'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );

      case 'canvasBg':
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _colorPalettes.map((p) {
              final isSelected = _selectedBgColor == p['color'];
              final color = _hexToColor(p['color']!);
              return GestureDetector(
                onTap: () => setState(() => _selectedBgColor = p['color']!),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white30,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
