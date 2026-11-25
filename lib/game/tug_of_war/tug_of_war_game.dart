import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../audio/audio.dart';
import '../../model/models.dart';
import '../../pixel/sprites.dart';
import '../../game/party_game.dart';
import '../../game/scoring.dart';

const double _kWinOffset = 100;
const double _kRopeRange = 220;

class TugOfWarGame extends PartyGame {
  TugOfWarGame({
    required super.session,
    required super.roster,
    required super.round,
    required super.totalRounds,
    required super.gameInfo,
    required super.onRoundFinish,
  });

  List<int> _teamA = [];
  List<int> _teamB = [];
  final Map<int, int> _teamOf = {};
  final Map<int, ui.Image> _avatars = {};
  double _offset = 0;
  double _renderOffset = 0;
  double _cpuTimer = 0;
  bool _cpuEnabled = false;
  final math.Random _rng = math.Random();

  @override
  FutureOr<void> onGameLoad() async {
    timeLeft = 45;
    final ids = activePlayers.map((p) => p.id).toList();
    final half = (ids.length + 1) ~/ 2;
    _teamA = ids.sublist(0, half);
    _teamB = ids.sublist(half);
    for (final id in ids) {
      _teamOf[id] = _teamA.contains(id) ? 0 : 1;
    }
    for (final p in activePlayers) {
      _avatars[p.id] = await avatarSprite(p.avatarId).imageAt(5);
    }
    world.add(_TugLayer(game: this));
  }

  @override
  void onStart() {
    _cpuEnabled = _teamB.isEmpty;
    Audio.whistle();
  }

  @override
  void simulate(double dt) {
    // Each fresh mash shoves the rope toward the masher's side.
    final sizeA = _teamA.length;
    final sizeB = _teamB.length;
    for (final id in [..._teamA, ..._teamB]) {
      final mashes = consumeMashes(id);
      if (mashes <= 0) continue;
      final team = _teamOf[id]!;
      final mySize = team == 0 ? sizeA : sizeB;
      final oppSize = team == 0 ? sizeB : sizeA;
      final soloBoost = (mySize == 1 && oppSize > 1) ? 1.75 : 1.0;
      final direction = team == 0 ? 1.0 : -1.0;
      _offset += direction * mashes * 1.18 * soloBoost;
      if (id != session.myPlayerId) {
        Audio.mash(); // quietly confirm remote mashers
      }
    }

    // CPU fills an empty side.
    if (_cpuEnabled) {
      _cpuTimer += dt;
      if (_cpuTimer > 0.14) {
        _cpuTimer = 0;
        _offset -= 1.18; // ghost pulls toward team B
        if (_rng.nextDouble() < 0.25) _offset -= 1.18; // burst streaks
      }
    }

    _offset = _offset.clamp(-_kWinOffset, _kWinOffset);
    _renderOffset += (_offset - _renderOffset) * 0.35;

    if (_offset.abs() >= _kWinOffset || timeLeft <= 0) {
      finishRound();
    }
  }

  @override
  Map<String, dynamic> buildSnapshot() => {
        'offset': _offset,
        'timeLeft': timeLeft,
      };

  @override
  void applySnapshot(Map<String, dynamic> snap) {
    _offset = (snap['offset'] as num?)?.toDouble() ?? _offset;
    _renderOffset += (_offset - _renderOffset) * 0.5;
    timeLeft = (snap['timeLeft'] as num?)?.toDouble() ?? timeLeft;
  }

  @override
  List<PlacementResult> computeResults() {
    if (_offset == 0) {
      // Dead heat: everyone splits the spoils.
      return tiedPoints([[..._teamA, ..._teamB]]);
    }
    final aWon = _offset > 0;
    return teamPoints(
      aWon ? _teamA : _teamB,
      aWon ? _teamB : _teamA,
    );
  }
}

class _TugLayer extends PositionComponent {
  _TugLayer({required this.game});

  final TugOfWarGame game;
  final Paint _avatarPaint = Paint()..filterQuality = FilterQuality.none;

  // Field stripes get precomputed for a cheap paint each frame.
  @override
  void render(Canvas canvas) {
    // Sky strip + grass.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kWorldW, 86),
      Paint()..color = const Color(0xff1a2033),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 86, kWorldW, kWorldH - 86),
      Paint()..color = const Color(0xff16301f),
    );
    // Slanted mowing stripes.
    final stripe = Paint()..color = const Color(0xff1c3a26);
    const slant = (kWorldH - 86) * 0.45;
    for (var x = -kWorldW; x < kWorldW + kWorldH; x += 92) {
      final path = Path()
        ..moveTo(x.toDouble(), 86)
        ..lineTo(x + 34.0, 86)
        ..lineTo(x + 34.0 + slant, kWorldH)
        ..lineTo(x + slant, kWorldH)
        ..close();
      canvas.drawPath(path, stripe);
    }

    const ropeY = 268.0;
    final shift = game._renderOffset * 2.2;

    // Win-zone bands at ±220 px from centre.
    final zoneA = Paint()
      ..color = const Color(0x334cc9f0)
      ..style = PaintingStyle.fill;
    final zoneB = Paint()
      ..color = const Color(0x33ef476f)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(kWorldW / 2 + _kRopeRange - 4, 86, 8, kWorldH - 86), zoneA);
    canvas.drawRect(
        Rect.fromLTWH(kWorldW / 2 - _kRopeRange - 4, 86, 8, kWorldH - 86), zoneB);

    // Centre line.
    final centrePaint = Paint()
      ..color = const Color(0xffffffff)
      ..strokeWidth = 3;
    for (var y = 90.0; y < kWorldH; y += 22) {
      canvas.drawLine(Offset(kWorldW / 2, y), Offset(kWorldW / 2, y + 11), centrePaint);
    }

    // Rope.
    final anchorA = Offset(kWorldW / 2 - 300 + shift, ropeY);
    final anchorB = Offset(kWorldW / 2 + 300 + shift, ropeY);
    canvas.drawLine(anchorA, anchorB,
        Paint()..color = const Color(0xff141419)..strokeWidth = 14);
    canvas.drawLine(anchorA, anchorB,
        Paint()..color = const Color(0xff8b5a2b)..strokeWidth = 9);
    // Rope texture ticks.
    final tickPaint = Paint()
      ..color = const Color(0xff5a3817)
      ..strokeWidth = 2;
    for (var t = 0.0; t <= 1.0; t += 0.045) {
      final p = Offset.lerp(anchorA, anchorB, t)!;
      canvas.drawLine(p + const Offset(0, -6), p + const Offset(0, 6), tickPaint);
    }

    // Centre knot + flag.
    final knot = Offset(kWorldW / 2 + shift, ropeY);
    canvas.drawCircle(knot, 12, Paint()..color = const Color(0xffffd166));
    canvas.drawCircle(knot, 12,
        Paint()..color = const Color(0xff141419)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(knot, knot + const Offset(0, -46),
        Paint()..color = const Color(0xff141419)..strokeWidth = 3);
    final flagPaint = Paint()..color = const Color(0xffef476f);
    canvas.drawRect(Rect.fromLTWH(knot.dx, knot.dy - 46, 26, 16), flagPaint);

    // Team banners.
    _banner(canvas, 'TEAM BLUE', 60, 112, const Color(0xff4cc9f0));
    _banner(canvas, 'TEAM RED', kWorldW - 60, 112, const Color(0xffef476f));

    // Players.
    final positionsA = game._teamA.length == 1
        ? [const Offset(0, 0)]
        : [const Offset(0, -46), const Offset(0, 46), const Offset(0, 0), const Offset(0, -92), const Offset(0, 92)];
    final positionsB = positionsA;
    for (var i = 0; i < game._teamA.length; i++) {
      final pos = Offset(110 + shift, ropeY + positionsA[i].dy);
      _drawPlayer(canvas, game._teamA[i], pos, const Color(0xff4cc9f0));
    }
    for (var i = 0; i < game._teamB.length; i++) {
      final pos = Offset(kWorldW - 110 + shift, ropeY + positionsB[i].dy);
      _drawPlayer(canvas, game._teamB[i], pos, const Color(0xffef476f));
    }
    if (game._teamB.isEmpty) {
      // Ghost opponent marker.
      final pos = Offset(kWorldW - 110 + shift, ropeY);
      canvas.drawCircle(pos, 26, Paint()..color = const Color(0x44ffffff));
      final ghost = strokeText(size: 7, color: const Color(0x99ffffff));
      ghost.render(canvas, 'GHOST', Vector2(pos.dx - 24, pos.dy - 4));
    }
  }

  void _banner(Canvas canvas, String text, double x, double y, Color color) {
    final paint = strokeText(size: 10, color: color);
    final w = textWidthOf(paint, text);
    paint.render(canvas, text, Vector2(x - w / 2, y));
  }

  void _drawPlayer(Canvas canvas, int id, Offset pos, Color teamColor) {
    final image = game._avatars[id];
    canvas.drawCircle(pos, 30, Paint()..color = teamColor.withValues(alpha: 0.35));
    if (image != null) {
      drawAvatar(
        canvas,
        image,
        Vector2(pos.dx, pos.dy - 4),
        58,
        _avatarPaint,
      );
    }
    final name = _playerName(id);
    final tag = strokeText(size: 7, color: Colors.white);
    final w = textWidthOf(tag, name);
    tag.render(canvas, name, Vector2(pos.dx - w / 2, pos.dy + 30));
  }

  String _playerName(int id) {
    for (final p in game.roster) {
      if (p.id == id) return p.name.toUpperCase();
    }
    return 'P';
  }
}
