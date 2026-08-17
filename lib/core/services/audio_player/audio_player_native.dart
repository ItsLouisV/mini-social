import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'app_audio_player.dart';

class NativeAppAudioPlayer implements AppAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String url, {bool loop = false}) async {
    try {
      await _player.stop();
      if (url.isEmpty) return;
      if (loop) {
        await _player.setReleaseMode(ReleaseMode.loop);
      } else {
        await _player.setReleaseMode(ReleaseMode.release);
      }
      await _player.setVolume(1.0);
      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('Native audio play error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
  }
}

AppAudioPlayer getAudioPlayer() => NativeAppAudioPlayer();
