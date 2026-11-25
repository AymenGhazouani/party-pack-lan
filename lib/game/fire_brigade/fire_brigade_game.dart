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

const double _kFireX = kWorldW / 2;
const double _kFireY = 236;
const double _kStartRadius = 74;
const double _kMaxRadius = 232;
const double _kWinRadius = 12;
const double _kGrowRate = 2.25;
const double _kSprayPower = 6.3;
const double _kSprayRangeBonus = 48;

class _FirePlayer {
  _FirePlayer(this.id);

  final int id;
  Vector2 pos = Vector2.zero();
  Vector2 vel = Vector2.zero();
  Vector2 facing = Vector2(0, -1);
  Vector2 renderPos = Vector2.zero();
  bool spraying = false;
  double stunT = 0;
}

class FireBrigadeGame extends PartyGame {
  FireBrigadeGame({
    required super.session,
    required super.roster,
    required super.round,
    required super.totalRounds,
    required super.gameInfo,
    required super.onRoundFinish,
  });

  double _radius = _kStartRadius;
  double _renderRadius = _kStartRadius;
  bool _success = false;
  final Map<int, _FirePlayer> _players = {};

  double get _visualT => DateTime.now().millisecondsSinceEpoch / 1000.0;
  final Map<int, ui.Image> _avatars = {};
  ui.Image? _ember;

  @override
  FutureOr<void> onGameLoad() async {
    timeLeft = 75;
    final players = activePlayers;
    for (var i = 0; i < players.length; i++) {
      final p = players[i];
      final angle = math.pi / 2 + 2 * math.pi * i / math.max(1, players.length);
      final fp = _FirePlayer(p.id)
        ..pos = Vector2(
          _kFireX + math.cos(angle) * (_kStartRadius + 88),
          _kFireY + math.sin(angle) * (_kStartRadius + 88),
        )
        ..renderPos = Vector2.zero();
      fp.renderPos = fp.pos.clone();
      fp.facing = (Vector2(_kFireX, _kFireY) - fp.pos).normalized();
      _players[p.id] = fp;
      _avatars[p.id] = await avatarSprite(p.avatarId).imageAt(5);
    }
    _ember = await emberSprite.imageAt(2);
    world.add(_FireLayer(game: this));
  }

  @override
  bool get coOpSuccess => _success;

  @override
  void simulate(double dt) {
    // Movement + spray state.
    for (final entry in _players.entries) {
      final fp = entry.value;
      final input = inputFor(entry.key);
      fp.stunT = math.max(0, fp.stunT - dt);

      final dir = Vector2(input.x, input.y);
      final len = dir.length;
      if (len > 0.15) {
        fp.facing = dir.normalized();
      }
      fp.spraying = input.action && fp.stunT <= 0;

      if (fp.stunT <= 0) {
        const accel = 2300.0;
        fp.vel += dir * accel * dt;
        fp.vel *= math.max(0.0, 1 - 5.4 * dt);
        if (fp.vel.length > 300) fp.vel.scale(300 / fp.vel.length);
        fp.pos += fp.vel * dt;
      } else {
        fp.vel *= math.max(0.0, 1 - 8 * dt);
        fp.pos += fp.vel * dt;
      }
      fp.pos.x = fp.pos.x.clamp(24, kWorldW - 24);
      fp.pos.y = fp.pos.y.clamp(48, kWorldH - 20);

      // Scorched by the fire: knock out of the blaze.
      final toPlayer = fp.pos - Vector2(_kFireX, _kFireY);
      final dist = toPlayer.length;
      if (dist < _radius - 8) {
        final normal = dist < 0.001 ? Vector2(1, 0) : toPlayer.normalized();
        fp.pos = Vector2(_kFireX, _kFireY) + normal * (_radius + 2);
        fp.vel += normal * 420;
        fp.stunT = 0.9;
        Audio.fireHit();
      }
    }

    // Fire growth & spray shrink.
    var shrink = 0.0;
    for (final entry in _players.entries) {
      final fp = entry.value;
      if (!fp.spraying) continue;
      final dist = (fp.pos - Vector2(_kFireX, _kFireY)).length;
      if (dist <= _radius + _kSprayRangeBonus) {
        shrink += _kSprayPower;
      }
    }
    _radius += (_kGrowRate - shrink) * dt;
    _radius = _radius.clamp(0, _kMaxRadius + 1);
    _renderRadius += (_radius - _renderRadius) * 0.25;

    if (_radius <= _kWinRadius) {
      _success = true;
      finishRound();
    } else if (_radius >= _kMaxRadius) {
      _success = false;
      finishRound();
    } else if (timeLeft <= 0) {
      _success = _radius < _kMaxRadius / 2;
      finishRound();
    }
  }

  @override
  Map<String, dynamic> buildSnapshot() => {
        'radius': _radius,
        'timeLeft': timeLeft,
        'players': [
          for (final entry in _players.entries)
            {
              'id': entry.key,
              'x': entry.value.pos.x,
              'y': entry.value.pos.y,
              'fx': entry.value.facing.x,
              'fy': entry.value.facing.y,
              'spray': entry.value.spraying,
              'stun': entry.value.stunT > 0,
            },
        ],
      };

  @override
  void applySnapshot(Map<String, dynamic> snap) {
    _radius = (snap['radius'] as num?)?.toDouble() ?? _radius;
    _renderRadius += (_radius - _renderRadius) * 0.5;
    timeLeft = (snap['timeLeft'] as num?)?.toDouble() ?? timeLeft;
    for (final raw in (snap['players'] as List<dynamic>? ?? [])) {
      final m = raw as Map<String, dynamic>;
      final fp = _players[m['id']];
      if (fp == null) continue;
      fp.pos = Vector2((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
      fp.facing = Vector2(
        (m['fx'] as num?)?.toDouble() ?? 0,
        (m['fy'] as num?)?.toDouble() ?? 0,
      );
      if (fp.facing.length > 0.01) fp.facing.normalize();
      fp.spraying = m['spray'] as bool? ?? false;
      fp.stunT = (m['stun'] as bool? ?? false) ? 0.4 : 0;
    }
  }

  @override
  List<PlacementResult> computeResults() =>
      coopPoints(activePlayers.map((p) => p.id).toList(), _success);
}

class _FireLayer extends PositionComponent {
  _FireLayer({required this.game});

  final FireBrigadeGame game;
  final Paint _avatarPaint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    // Back alley ground.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kWorldW, kWorldH),
      Paint()..color = const Color(0xff1a1410),
    );
    // Floor tiles (subtle checker).
    final tile = Paint()..color = const Color(0xff201a16);
    const tileSize = 64.0;
    for (var y = 48.0; y < kWorldH; y += tileSize) {
      for (var x = 0.0; x < kWorldW; x += tileSize) {
        if (((x / tileSize) + (y / tileSize)).floor().isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, tileSize, tileSize), tile);
        }
      }
    }
    // Danger scorch ring.
    canvas.drawCircle(
      const Offset(_kFireX, _kFireY),
      game._renderRadius + 18,
      Paint()..color = const Color(0x33120b06),
    );

    // Fire.
    final r = game._renderRadius;
    final t = game._visualT;
    final flicker = math.sin(t * 7.3) * 4 + math.sin(t * 11.7 + 1.3) * 2.5;
    // Outer glow
    canvas.drawCircle(
      const Offset(_kFireX, _kFireY),
      r * 1.42,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x66ff7722), Color(0x00ff7722)],
        ).createShader(Rect.fromCircle(center: const Offset(_kFireX, _kFireY), radius: r * 1.42)),
    );
    canvas.drawCircle(const Offset(_kFireX, _kFireY), r,
        Paint()..color = const Color(0xffd84e12));
    canvas.drawCircle(Offset(_kFireX, _kFireY - r * 0.08), (r * 0.76) + flicker,
        Paint()..color = const Color(0xfff4842b));
    canvas.drawCircle(Offset(_kFireX, _kFireY - r * 0.14), (r * 0.5) + flicker * 1.4,
        Paint()..color = const Color(0xffffd23f));
    // Rim flame tongues.
    final ember = game._ember;
    if (ember != null) {
      for (var i = 0; i < 12; i++) {
        final angle = i * math.pi / 6 + t * 0.55;
        final wobble = 16 + math.sin(t * 9 + i * 2.1) * 9;
        final pos = Offset(_kFireX + math.cos(angle) * (r + wobble * 0.4),
            _kFireY + math.sin(angle) * (r + wobble * 0.4));
        final size = 26 + math.sin(t * 12 + i * 1.7) * 9;
        canvas.drawImageRect(
          ember,
          Rect.fromLTWH(0, 0, ember.width.toDouble(), ember.height.toDouble()),
          Rect.fromCenter(center: pos, width: size, height: size * ember.height / ember.width),
          _avatarPaint,
        );
      }
    }

    // Water cones + players.
    for (final entry in game._players.entries) {
      final fp = entry.value;
      fp.renderPos += (fp.pos - fp.renderPos) * 0.5;
      if (fp.spraying) {
        _drawSpray(canvas, fp.renderPos, fp.facing);
      }
    }
    for (final entry in game._players.entries) {
      final fp = entry.value;
      final avatar = game._avatars[entry.key];
      if (avatar != null) {
        drawAvatar(canvas, avatar, fp.renderPos, 56, _avatarPaint);
        if (fp.stunT > 0) {
          canvas.drawCircle(
            Offset(fp.renderPos.x, fp.renderPos.y),
            30,
            Paint()..color = const Color(0x55ef476f),
          );
          final splash = strokeText(size: 12, color: const Color(0xffef476f));
          splash.render(
            canvas,
            '!!',
            Vector2(fp.renderPos.x - 8, fp.renderPos.y - 52),
          );
        }
      }
      final name = _playerName(entry.key);
      final tag = strokeText(size: 7, color: Colors.white);
      final w = textWidthOf(tag, name);
      tag.render(canvas, name,
          Vector2(fp.renderPos.x - w / 2, fp.renderPos.y + 30));
    }

    // Fire HP bar.
    _drawFireBar(canvas);
  }

  void _drawSpray(Canvas canvas, Vector2 from, Vector2 facing) {
    final dir = facing.length > 0.01 ? facing.normalized() : Vector2(0, -1);
    final perpendicular = Vector2(-dir.y, dir.x);
    final reach = 120.0;
    final spread = 0.55;
    final tip = from + dir * reach;
    final left = tip - perpendicular * (reach * spread);
    final right = tip + perpendicular * (reach * spread);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xcce8fbff), Color(0xffe8fbff), Color(0x00e8fbff)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromPoints(Offset(from.x, from.y), Offset(tip.x, tip.y)));
    canvas.drawPath(
      Path()
        ..moveTo(from.x, from.y)
        ..lineTo(left.x, left.y)
        ..lineTo(right.x, right.y)
        ..close(),
      paint,
    );
    // Droplets.
    final t = game._visualT;
    final drop = Paint()..color = const Color(0xbbe8fbff);
    for (var i = 0; i < 6; i++) {
      final phase = (t * 3.2 + i * 0.17) % 1.0;
      final dist = phase * reach;
      final side = math.sin(i * 2.4 + t * 8) * reach * spread * phase;
      final p = from + dir * dist + perpendicular * side;
      canvas.drawCircle(Offset(p.x, p.y), 3.2 + phase * 2, drop);
    }
  }

  void _drawFireBar(Canvas canvas) {
    final r = game._renderRadius;
    final frac = ((r - _kWinRadius) / (_kMaxRadius - _kWinRadius)).clamp(0.0, 1.0);
    const barW = 300.0;
    const barH = 16.0;
    const x = (kWorldW - barW) / 2;
    const y = 44.0;
    canvas.drawRect(Rect.fromLTWH(x - 2, y - 2, barW + 4, barH + 4),
        Paint()..color = const Color(0xff141419));
    canvas.drawRect(Rect.fromLTWH(x, y, barW, barH),
        Paint()..color = const Color(0xff2e1a10));
    final fill = frac > 0.66
        ? const Color(0xffef476f)
        : frac > 0.33
            ? const Color(0xfff78c2b)
            : const Color(0xffffd166);
    canvas.drawRect(Rect.fromLTWH(x, y, barW * frac, barH), Paint()..color = fill);
    final label = strokeText(size: 8, color: Colors.white);
    label.render(canvas, 'FIRE', Vector2(x - 44, y + 2));
  }

  String _playerName(int id) {
    for (final p in game.roster) {
      if (p.id == id) return p.name.toUpperCase();
    }
    return 'P';
  }
}
