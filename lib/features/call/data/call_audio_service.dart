import 'package:flutter/foundation.dart';
import '../../../core/services/audio_player/app_audio_player.dart';

/// Quản lý âm thanh cho màn hình call (ringtone gọi đến / dialtone gọi đi)
class CallAudioService {
  static final CallAudioService _instance = CallAudioService._();
  factory CallAudioService() => _instance;
  CallAudioService._();

  AppAudioPlayer? _player;
  int _operation = 0;

  /// Phát tiếng chuông gọi đến (lặp lại)
  Future<void> playRingtone() async {
    final operation = ++_operation;
    await _stop();
    if (operation != _operation) return;
    final player = createAudioPlayer();
    _player = player;
    if (operation == _operation) {
      await player.play('assets/sounds/ringtone.mp3', loop: true);
    }
  }

  /// Phát tiếng gọi đi / dialtone (lặp lại)
  Future<void> playDialtone() async {
    final operation = ++_operation;
    await _stop();
    if (operation != _operation) return;
    final player = createAudioPlayer();
    _player = player;
    if (operation == _operation) {
      await player.play('assets/sounds/dialtone.mp3', loop: true);
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
      _player?.dispose();
    } catch (e) {
      debugPrint('CallAudioService stop error: $e');
    }
    _player = null;
  }
}
