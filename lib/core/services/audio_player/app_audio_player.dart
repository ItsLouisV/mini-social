import 'audio_player_stub.dart'
    if (dart.library.html) 'audio_player_web.dart'
    if (dart.library.io) 'audio_player_native.dart';

abstract class AppAudioPlayer {
  factory AppAudioPlayer() => getAudioPlayer();

  Future<void> play(String url, {bool loop = false});
  Future<void> stop();
  Future<void> pause();
  void dispose();
}

AppAudioPlayer createAudioPlayer() => AppAudioPlayer();
