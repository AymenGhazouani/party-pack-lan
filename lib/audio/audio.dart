import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

/// Thin wrapper around flame_audio so call sites don't depend on it directly.
class Audio {
  Audio._();

  static void init() {
    // Deliberately not awaited: plugin setup is best-effort and must never
    // block app boot (or widget tests under FakeAsync).
    try {
      unawaited(FlameAudio.bgm.initialize().catchError((_) {}));
    } catch (_) {}
  }

  static Future<void> play(String file, {double volume = 1.0}) async {
    try {
      await FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }

  static Future<void> playLobby() => _playMusic('music_lobby.wav', 0.5);
  static Future<void> playGame() => _playMusic('music_game.wav', 0.45);
  static Future<void> playPodium() => _playMusic('music_podium.wav', 0.6);

  static Future<void> _playMusic(String file, double volume) async {
    try {
      // Fire-and-forget: on platforms where the audio channel never replies
      // (tests, headless), we must not hang app boot.
      unawaited(FlameAudio.bgm.play(file, volume: volume).catchError((_) {}));
    } catch (_) {}
  }

  static Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  // Named SFX
  static Future<void> tap() => play('tap.wav', volume: 0.5);
  static Future<void> confirm() => play('confirm.wav');
  static Future<void> back() => play('back.wav', volume: 0.6);
  static Future<void> select() => play('select.wav', volume: 0.7);
  static Future<void> tick() => play('tick.wav', volume: 0.8);
  static Future<void> go() => play('go.wav');
  static Future<void> mash() => play('mash.wav', volume: 0.55);
  static Future<void> hit() => play('hit.wav');
  static Future<void> gem() => play('gem.wav', volume: 0.8);
  static Future<void> bomb() => play('bomb.wav');
  static Future<void> spray() => play('spray.wav', volume: 0.35);
  static Future<void> fireHit() => play('fire_hit.wav', volume: 0.8);
  static Future<void> point() => play('point.wav', volume: 0.8);
  static Future<void> win() => play('win.wav');
  static Future<void> lose() => play('lose.wav');
  static Future<void> whistle() => play('whistle.wav');
}
