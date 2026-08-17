import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/audio_player/app_audio_player.dart';

import '../../domain/music_track_model.dart';
import '../../providers/music_provider.dart';

class MusicPickerModal extends ConsumerStatefulWidget {
  final MusicTrackModel? initialSelectedTrack;

  const MusicPickerModal({
    super.key,
    this.initialSelectedTrack,
  });

  static Future<MusicTrackModel?> show(
    BuildContext context, {
    MusicTrackModel? currentTrack,
  }) {
    return showModalBottomSheet<MusicTrackModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPickerModal(initialSelectedTrack: currentTrack),
    );
  }

  @override
  ConsumerState<MusicPickerModal> createState() => _MusicPickerModalState();
}

class _MusicPickerModalState extends ConsumerState<MusicPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  late final AppAudioPlayer _audioPlayer;
  Timer? _debounceTimer;

  String? _previewTrackId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = createAudioPlayer();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref.read(musicSearchQueryProvider.notifier).state = query;
      }
    });
  }

  Future<void> _togglePreview(MusicTrackModel track) async {
    if (_previewTrackId == track.id && _isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.stop();
      setState(() {
        _previewTrackId = track.id;
        _isPlaying = true;
      });
      try {
        await _audioPlayer.play(track.previewUrl);
      } catch (e) {
        debugPrint('Audio preview error: $e');
        if (mounted) {
          setState(() {
            _previewTrackId = null;
            _isPlaying = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final searchResultsAsync = ref.watch(musicSearchResultsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.music_note_2, color: Color(0xFF38BDF8), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Chọn nhạc nền',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm bài hát, ca sĩ...',
                prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(CupertinoIcons.clear_thick_circled, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Track List
          Expanded(
            child: searchResultsAsync.when(
              data: (tracks) {
                if (tracks.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy bài hát nào'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final isThisPreviewing = _previewTrackId == track.id && _isPlaying;
                    final isSelected = widget.initialSelectedTrack?.id == track.id;

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CachedNetworkImage(
                                imageUrl: track.getHighResArtworkUrl(100),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey.shade300),
                                errorWidget: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey.shade800,
                                  child: const Icon(CupertinoIcons.music_note, color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isThisPreviewing
                                      ? CupertinoIcons.pause_fill
                                      : CupertinoIcons.play_fill,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () => _togglePreview(track),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          track.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            _audioPlayer.stop();
                            Navigator.pop(context, track);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 0,
                          ),
                          child: const Text('Chọn', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.wifi_exclamationmark,
                          size: 44, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tải được danh sách nhạc',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kIsWeb
                            ? 'Trình duyệt có thể đang chặn kết nối. Hãy thử lại.'
                            : 'Kiểm tra kết nối mạng và thử lại.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref.invalidate(musicSearchResultsProvider);
                        },
                        icon: const Icon(CupertinoIcons.refresh, size: 16),
                        label: const Text('Thử lại'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
