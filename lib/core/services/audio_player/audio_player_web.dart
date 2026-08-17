// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'app_audio_player.dart';

class WebAppAudioPlayer implements AppAudioPlayer {
  html.AudioElement? _audioElement;

  @override
  Future<void> play(String url, {bool loop = false}) async {
    await stop();
    if (url.isEmpty) return;
    try {
      _audioElement = html.AudioElement(url)
        ..loop = loop
        ..crossOrigin = 'anonymous'
        ..autoplay = true;
      _audioElement!.load();
      await _audioElement!.play();
    } catch (e) {
      debugPrint('Web native audio play notice: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (_audioElement != null) {
      try {
        _audioElement!.pause();
        _audioElement!.removeAttribute('src');
        _audioElement!.load();
      } catch (_) {}
      _audioElement = null;
    }
  }

  @override
  Future<void> pause() async {
    try {
      _audioElement?.pause();
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
  }
}

AppAudioPlayer getAudioPlayer() => WebAppAudioPlayer();
