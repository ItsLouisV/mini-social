import 'app_audio_player.dart';

class StubAppAudioPlayer implements AppAudioPlayer {
  @override
  Future<void> play(String url, {bool loop = false}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  void dispose() {}
}

AppAudioPlayer getAudioPlayer() => StubAppAudioPlayer();
