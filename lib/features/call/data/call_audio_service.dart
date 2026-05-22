import 'package:audioplayers/audioplayers.dart';

/// Quản lý âm thanh cho màn hình call (ringtone gọi đến / dialtone gọi đi)
class CallAudioService {
  static final CallAudioService _instance = CallAudioService._();
  factory CallAudioService() => _instance;
  CallAudioService._();

  AudioPlayer? _player;

  /// Phát tiếng chuông gọi đến (lặp lại)
  Future<void> playRingtone() async {
    await _stop();
    _player = AudioPlayer();
    await _player!.setReleaseMode(ReleaseMode.loop);
    await _player!.setVolume(1.0);
    await _player!.play(AssetSource('sounds/ringtone.mp3'));
  }

  /// Phát tiếng gọi đi / dialtone (lặp lại, nhỏ hơn)
  Future<void> playDialtone() async {
    await _stop();
    _player = AudioPlayer();
    await _player!.setReleaseMode(ReleaseMode.loop);
    await _player!.setVolume(0.5);
    await _player!.play(AssetSource('sounds/dialtone.mp3'));
  }

  /// Dừng âm thanh hiện tại
  Future<void> stop() => _stop();

  Future<void> _stop() async {
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
