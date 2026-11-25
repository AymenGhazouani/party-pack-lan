import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/audio.dart';
import '../config.dart';
import '../model/models.dart';
import '../net/network_session.dart';
import '../state/input_bus.dart';
import 'game_registry.dart';

const double kWorldW = kWorldWidth;
const double kWorldH = kWorldHeight;

/// Common skeleton for every mini-game: countdown, snapshot broadcast,
/// client input upload, HUD chrome and the round-finish callback.
///
/// Host runs the authoritative simulation ([simulate]); clients receive
/// snapshots ([applySnapshot]) and send their local input at 30 Hz.
abstract class PartyGame extends FlameGame {
  PartyGame({
    required this.session,
    required this.roster,
    required this.round,
    required this.totalRounds,
    required this.gameInfo,
    required this.onRoundFinish,
    this.countdownSeconds = 3.0,
  }) : super(
          camera: CameraComponent(
            viewport: FixedResolutionViewport(
              resolution: Vector2(kWorldW, kWorldH),
            ),
          ),
        ) {
    // Anchor the world origin at the viewport's top-left corner, otherwise
    // Flame centres (0,0) and the whole arena spills into one quadrant.
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
  }

  final NetworkSession session;
  final List<PlayerInfo> roster;
  final int round;
  final int totalRounds;
  final GameInfo gameInfo;
  final void Function(List<PlacementResult> results, bool coOpSuccess)
      onRoundFinish;
  final double countdownSeconds;

  final ValueNotifier<int> countdown = ValueNotifier(3);

  bool playing = false;
  bool finished = false;
  double timeLeft = 0;
  double _countdownLeft = 3.0;
  double _snapshotTimer = 0;
  double _inputTimer = 0;
  int _snapshotSeq = 0;

  /// Client input slots, keyed by player id (host only).
  final Map<int, InputPacket> remoteInputs = {};
  final Map<int, int> _lastMash = {};

  bool get isHost => session.isHost;

  /// Players present at round start, preserving host-first join order.
  List<PlayerInfo> get activePlayers =>
      roster.where((p) => p.connected).toList(growable: false);

  @override
  FutureOr<void> onLoad() async {
    _countdownLeft = countdownSeconds;
    countdown.value = countdownSeconds.ceil();
    if (!isHost) {
      session.onSnapshot = _handleSnapshot;
    } else {
      session.onInput = (playerId, input) => remoteInputs[playerId] = input;
    }
    world.add(HudChrome(game: this));
    await onGameLoad();
  }

  FutureOr<void> onGameLoad() {}

  /// The host has begun (and clients have passed) the countdown.
  void onStart() {}

  /// Host-only: advance the authoritative world.
  void simulate(double dt) {}

  /// Host-only: snapshot to broadcast to clients.
  Map<String, dynamic> buildSnapshot() => const {};

  /// Client-only: apply a snapshot received from the host.
  void applySnapshot(Map<String, dynamic> snap) {}

  /// Host-only: build the ranking once the game is decided.
  List<PlacementResult> computeResults();

  /// Co-op games: whether the team achieved its objective.
  bool get coOpSuccess => false;

  InputPacket localInput() => InputPacket(
        x: inputBus.x,
        y: inputBus.y,
        action: inputBus.action,
        dash: inputBus.dash,
        mash: inputBus.mash,
      );

  /// Input for [playerId] — local bus for the host, remote packet otherwise.
  InputPacket inputFor(int playerId) {
    if (isHost && playerId == session.myPlayerId) return localInput();
    return remoteInputs[playerId] ?? const InputPacket();
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = dt.clamp(0.0, 1 / 20); // never tunnel after a frame hitch
    if (finished) return;
    if (!playing) {
      _tickCountdown(dt);
      return;
    }
    timeLeft = math.max(0, timeLeft - dt);
    if (isHost) {
      simulate(dt);
      _snapshotTimer += dt;
      if (_snapshotTimer >= 0.05) {
        _snapshotTimer = 0;
        _snapshotSeq++;
        session.broadcastSnapshot({
          'type': 'snap',
          'game': gameInfo.id,
          'seq': _snapshotSeq,
          't': DateTime.now().millisecondsSinceEpoch,
          'state': buildSnapshot(),
        });
      }
    } else {
      _inputTimer += dt;
      if (_inputTimer >= 1 / 30) {
        _inputTimer = 0;
        session.sendInput(localInput());
      }
    }
  }

  void _tickCountdown(double dt) {
    _countdownLeft -= dt;
    final next = _countdownLeft.ceil().clamp(0, countdownSeconds.ceil());
    if (next != countdown.value) {
      countdown.value = next;
      if (next > 0) {
        Audio.tick();
      }
    }
    if (_countdownLeft <= 0 && !playing) {
      playing = true;
      countdown.value = 0;
      Audio.go();
      onStart();
    }
  }

  void _handleSnapshot(Map<String, dynamic> snap) {
    if (!playing || finished) return;
    final game = snap['game'];
    if (game != gameInfo.id) return;
    final state = snap['state'];
    if (state is Map<String, dynamic>) applySnapshot(state);
  }

  /// Host-only: how many fresh mashes has [playerId] produced since the last call?
  int consumeMashes(int playerId) {
    final last = _lastMash[playerId] ?? 0;
    final current = isHost && playerId == session.myPlayerId
        ? inputBus.mash
        : (remoteInputs[playerId]?.mash ?? 0);
    final delta = current - last;
    _lastMash[playerId] = current;
    return delta < 0 ? 0 : delta;
  }

  /// Host-only: decide the round exactly once and report it upstream.
  void finishRound() {
    if (finished || !isHost) return;
    finished = true;
    final bool coop = gameInfo.mode == GameMode.coop;
    onRoundFinish(computeResults(), coop ? coOpSuccess : false);
  }
}

/// Fixed HUD chrome drawn on top of every mini-game: game title (left),
/// timer (center), round (right).
class HudChrome extends PositionComponent {
  HudChrome({required this.game}) : super(priority: 1000);

  final PartyGame game;
  final Paint _scrim = Paint()..color = const Color(0x66000000);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, kWorldW, 38), _scrim);
    final title = TextPaint(
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 13,
        color: Color(0xffcfd2dc),
      ),
    );
    final clockText = game.timeLeft.ceil().clamp(0, 999);
    final timeStr = '${clockText ~/ 60}:${(clockText % 60).toString().padLeft(2, '0')}';
    title.render(canvas, game.gameInfo.title, Vector2(14, 12));
    final clock = TextPaint(
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 20,
        color: Color(0xffffd166),
      ),
    );
    final clockW = textWidthOf(clock, timeStr);
    clock.render(canvas, timeStr, Vector2((kWorldW - clockW) / 2, 7));
    final round = TextPaint(
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 13,
        color: Color(0xffcfd2dc),
      ),
    );
    final roundStr = 'R ${game.round}/${game.totalRounds}';
    final rw = textWidthOf(round, roundStr);
    round.render(canvas, roundStr, Vector2(kWorldW - rw - 14, 12));
  }
}

/// Measure the pixel width of [text] rendered with [paint].
double textWidthOf(TextPaint paint, String text) =>
    paint.toTextPainter(text).width;

TextPaint strokeText({double size = 12, Color color = Colors.white}) =>
    TextPaint(
      style: TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: size,
        color: color,
        shadows: const [
          Shadow(color: Color(0xff141419), blurRadius: 0, offset: Offset(2, 2)),
        ],
      ),
    );

/// Draw an avatar sprite centred on [center]; [image] may be null (skips).
void drawAvatar(Canvas canvas, ui.Image image, Vector2 center, double size,
    Paint paint) {
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: size,
      height: size * image.height / image.width,
    ),
    paint,
  );
}
