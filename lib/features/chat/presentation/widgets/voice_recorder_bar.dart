import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

enum _RecorderStatus { recording, previewPaused, previewPlaying }

class VoiceRecorderBar extends StatefulWidget {
  final Color themeColor;
  final Function(List<int> bytes, int durationSeconds) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderBar({
    super.key,
    required this.themeColor,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderBar> createState() => _VoiceRecorderBarState();
}

class _VoiceRecorderBarState extends State<VoiceRecorderBar>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AnimationController _animController;
  AudioPlayer? _previewPlayer;

  _RecorderStatus _status = _RecorderStatus.recording;
  int _secondsRecorded = 0;
  Timer? _timer;
  List<int> _recordedBytes = [];
  String? _recordedPath;

  Duration _previewPosition = Duration.zero;
  StreamSubscription? _previewPosSub;
  StreamSubscription? _previewStateSub;

  static const List<double> _liveWaveBase = [
    0.4, 0.7, 0.2, 0.9, 1.2, 1.0, 0.5, 0.8, 0.3, 1.2, 0.9, 0.4, 0.7, 0.3, 0.1, 0.9, 0.6, 0.5
  ];

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _previewPosSub?.cancel();
    _previewStateSub?.cancel();
    _previewPlayer?.dispose();
    _animController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final RecordConfig config = const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 48000,
        );

        String? path;
        if (!kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _audioRecorder.start(config, path: path ?? '');

        setState(() {
          _status = _RecorderStatus.recording;
          _secondsRecorded = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted && _status == _RecorderStatus.recording) {
            setState(() {
              _secondsRecorded++;
            });
          }
        });
      } else {
        widget.onCancel();
      }
    } catch (e) {
      print('Error starting recorder: $e');
      widget.onCancel();
    }
  }

  // Dừng ghi âm và chuyển sang chế độ nghe thử (Preview Mode)
  Future<void> _stopAndPreview() async {
    _timer?.cancel();
    _animController.stop();
    try {
      final path = await _audioRecorder.stop();
      if (path != null && path.isNotEmpty && _secondsRecorded >= 1) {
        _recordedPath = path;
        final xfile = XFile(path);
        _recordedBytes = await xfile.readAsBytes();

        if (_recordedBytes.isNotEmpty) {
          setState(() {
            _status = _RecorderStatus.previewPaused;
          });
          return;
        }
      }
      widget.onCancel();
    } catch (e) {
      print('Error stopping for preview: $e');
      widget.onCancel();
    }
  }

  // Bật/tắt phát nghe thử âm thanh vừa ghi
  Future<void> _togglePreviewPlay() async {
    if (_recordedPath == null && _recordedBytes.isEmpty) return;

    if (_previewPlayer == null) {
      _previewPlayer = AudioPlayer();
      _previewPosSub = _previewPlayer!.onPositionChanged.listen((p) {
        if (mounted) setState(() => _previewPosition = p);
      });
      _previewStateSub = _previewPlayer!.onPlayerStateChanged.listen((s) {
        if (mounted) {
          setState(() {
            _status = (s == PlayerState.playing)
                ? _RecorderStatus.previewPlaying
                : _RecorderStatus.previewPaused;
          });
        }
      });
    }

    if (_status == _RecorderStatus.previewPlaying) {
      await _previewPlayer!.pause();
    } else {
      if (_recordedPath != null) {
        await _previewPlayer!.play(UrlSource(_recordedPath!));
      } else {
        await _previewPlayer!.play(BytesSource(Uint8List.fromList(_recordedBytes)));
      }
    }
  }

  Future<void> _confirmSend() async {
    _timer?.cancel();
    await _previewPlayer?.stop();

    if (_recordedBytes.isNotEmpty && _secondsRecorded >= 1) {
      widget.onSend(_recordedBytes, _secondsRecorded);
    } else {
      // Nếu chưa dừng ghi âm mà bấm gửi trực tiếp
      final path = await _audioRecorder.stop();
      if (path != null && path.isNotEmpty && _secondsRecorded >= 1) {
        final xfile = XFile(path);
        final bytes = await xfile.readAsBytes();
        if (bytes.isNotEmpty) {
          widget.onSend(bytes, _secondsRecorded);
          return;
        }
      }
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    await _previewPlayer?.stop();
    try {
      if (_status == _RecorderStatus.recording) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    widget.onCancel();
  }

  String _formatSeconds(int sec) {
    final m = (sec ~/ 60).toString().padLeft(1, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgContainerColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    final isPreview = _status == _RecorderStatus.previewPaused ||
        _status == _RecorderStatus.previewPlaying;
    final isPlaying = _status == _RecorderStatus.previewPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 1. Nút Hủy (Trash)
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 2. Khung sóng âm & Bộ đếm thời gian
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bgContainerColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    if (!isPreview) ...[
                      // Nút Tạm Dừng Ghi Âm để Nghe Thử
                      GestureDetector(
                        onTap: _stopAndPreview,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.pause_fill,
                            color: Colors.orange,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatSeconds(_secondsRecorded),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      // Dải sóng equalizer động khi đang ghi âm
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return SizedBox(
                            height: 18,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(_liveWaveBase.length, (index) {
                                final factor = (index % 2 == 0)
                                    ? _animController.value
                                    : (1.0 - _animController.value);
                                final height =
                                    4.0 + (_liveWaveBase[index] * 12.0 * factor);

                                return Container(
                                  width: 2.0,
                                  height: height,
                                  margin: const EdgeInsets.symmetric(horizontal: 0.8),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // Chế độ Nghe Thử (Preview Mode)
                      GestureDetector(
                        onTap: _togglePreviewPlay,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            color: widget.themeColor,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isPlaying
                            ? _formatSeconds(_previewPosition.inSeconds)
                            : _formatSeconds(_secondsRecorded),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: widget.themeColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Nghe lại',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 3. Nút Gửi (Paperplane)
            GestureDetector(
              onTap: _confirmSend,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.themeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.arrow_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
