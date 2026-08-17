// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'app_audio_player.dart';

class WebAppAudioPlayer implements AppAudioPlayer {
  html.AudioElement? _audioElement;

  html.AudioElement _getOrCreateAudioElement() {
    if (_audioElement == null) {
      _audioElement = html.AudioElement()
        ..crossOrigin = 'anonymous';
      html.document.body?.children.add(_audioElement!);
    }
    return _audioElement!;
  }

  String _resolveWebUrl(String url) {
    if (url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('blob:')) {
      return url;
    }
    if (url.startsWith('assets/')) {
      return 'assets/$url';
    }
    return 'assets/assets/$url';
  }

  @override
  Future<void> play(String url, {bool loop = false}) async {
    if (url.isEmpty) {
      await stop();
      return;
    }
    try {
      final resolvedUrl = _resolveWebUrl(url);
      final element = _getOrCreateAudioElement();
      element.pause();
      element.loop = loop;
      element.src = resolvedUrl;
      element.load();
      await element.play().catchError((err) {
        debugPrint('Safari autoplay notice: $err');
      });
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
      } catch (_) {}
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
    _audioElement?.remove();
    _audioElement = null;
  }
}

AppAudioPlayer getAudioPlayer() => WebAppAudioPlayer();
