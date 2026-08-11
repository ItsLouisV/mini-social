import 'package:audioplayers/audioplayers.dart';

/// Quản lý âm thanh cho màn hình call (ringtone gọi đến / dialtone gọi đi)
class CallAudioService {
  static final CallAudioService _instance = CallAudioService._();
  factory CallAudioService() => _instance;
  CallAudioService._();

  AudioPlayer? _player;
  int _operation = 0;

  /// Phát tiếng chuông gọi đến (lặp lại)
  Future<void> playRingtone() async {
    final operation = ++_operation;
    await _stop();
    if (operation != _operation) return;
    final player = AudioPlayer();
    _player = player;
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(1.0);
    if (operation == _operation) {
      await player.play(AssetSource('sounds/ringtone.mp3'));
    }
  }

  /// Phát tiếng gọi đi / dialtone (lặp lại, nhỏ hơn)
  Future<void> playDialtone() async {
    final operation = ++_operation;
    await _stop();
    if (operation != _operation) return;
    final player = AudioPlayer();
    _player = player;
    await player.setReleaseMode(ReleaseMode.loop);
    await player.setVolume(0.5);
    if (operation == _operation) {
      await player.play(AssetSource('sounds/dialtone.mp3'));
    }
  }

  /// Dừng âm thanh hiện tại
  Future<void> stop() {
    _operation++;
    return _stop();
  }

  Future<void> _stop() async {
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
