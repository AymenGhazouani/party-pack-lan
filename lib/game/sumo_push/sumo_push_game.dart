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

const double _kRingCenterX = kWorldW / 2;
const double _kRingCenterY = kWorldH / 2 + 8;
const double _kRingRadius = 168;
const double _kPlayerRadius = 24;
const double _kDashImpulse = 560;
const double _kDashCooldown = 1.4;

class _SimPlayer {
  _SimPlayer(this.id);

  final int id;
  Vector2 pos = Vector2.zero();
  Vector2 vel = Vector2.zero();
  bool alive = true;
  double fallAt = double.infinity; // seconds since round start, inf = standing
  double dashCooldown = 0;
  bool wasDash = false;
  Vector2 renderPos = Vector2.zero();
}

class SumoPushGame extends PartyGame {
  SumoPushGame({
    required super.session,
    required super.roster,
    required super.round,
    required super.totalRounds,
    required super.gameInfo,
    required super.onRoundFinish,
  });

  final List<_SimPlayer> _sim = [];
  final Map<int, _SimPlayer> _byId = {};
  final Map<int, ui.Image> _avatars = {};
  double _elapsed = 0;

  @override
  FutureOr<void> onGameLoad() async {
    timeLeft = 60;
    final players = activePlayers;
    final n = players.length;
    for (var i = 0; i < n; i++) {
      final p = players[i];
      _avatars[p.id] = await avatarSprite(p.avatarId).imageAt(5);
      final sp = _SimPlayer(p.id);
      final angle = -math.pi / 2 + 2 * math.pi * i / math.max(1, n);
      sp.pos = Vector2(
        _kRingCenterX + math.cos(angle) * _kRingRadius * 0.45,
        _kRingCenterY + math.sin(angle) * _kRingRadius * 0.45,
      );
      sp.renderPos = sp.pos.clone();
      _sim.add(sp);
      _byId[p.id] = sp;
    }
    world.add(_SumoLayer(game: this));
  }

  @override
  void simulate(double dt) {
    _elapsed += dt;
    // Per-player forces.
    for (final sp in _sim) {
      if (!sp.alive) continue;
      final input = inputFor(sp.id);
      sp.dashCooldown = math.max(0, sp.dashCooldown - dt);

      // Directional input with smoothing (accelerate toward desired).
      final desired = Vector2(input.x, input.y);
      final len = desired.length;
      if (len > 1) desired.scale(1 / len);
      const accel = 2400.0;
      sp.vel += desired * accel * dt;
      // Friction.
      sp.vel *= math.max(0.0, 1 - 5.2 * dt);
      final speed = sp.vel.length;
      if (speed > 380) sp.vel.scale(380 / speed);

      // Dash (edge-triggered via cooldown).
      if (input.dash && sp.dashCooldown <= 0) {
        var dir = desired.length > 0.15 ? desired.normalized() : null;
        dir ??= _awayFromCenter(sp.pos);
        sp.vel += dir * _kDashImpulse;
        sp.dashCooldown = _kDashCooldown;
        Audio.play('mash.wav', volume: 0.7);
      }

      sp.pos += sp.vel * dt;

      // Out of the ring?
      final fromCenter = sp.pos - Vector2(_kRingCenterX, _kRingCenterY);
      if (fromCenter.length > _kRingRadius - 4) {
        _eliminate(sp);
      }
    }

    // Pairwise collisions.
    for (var i = 0; i < _sim.length; i++) {
      final a = _sim[i];
      if (!a.alive) continue;
      for (var j = i + 1; j < _sim.length; j++) {
        final b = _sim[j];
        if (!b.alive) continue;
        final delta = b.pos - a.pos;
        final dist = delta.length;
        if (dist == 0 || dist >= _kPlayerRadius * 2) continue;
        final normal = delta / dist;
        // Resolve overlap.
        final overlap = _kPlayerRadius * 2 - dist;
        a.pos -= normal * overlap / 2;
        b.pos += normal * overlap / 2;
        // Exchange velocity along normal (restitution ~0.9).
        final relVel = (b.vel - a.vel).dot(normal);
        if (relVel < 0) {
          const restitution = 0.9;
          final impulse = -(1 + restitution) * relVel / 2;
          a.vel -= normal * impulse;
          b.vel += normal * impulse;
          // Extra shove: faster mover knocks the other further back.
          final shove = a.vel.length > b.vel.length ? a.vel.length : b.vel.length;
          if (shove > 120) {
            final kick = normal * (shove * 0.35);
            if (a.vel.length > b.vel.length) {
              b.vel += kick;
            } else {
              a.vel -= kick;
            }
            Audio.play('hit.wav', volume: 0.5);
          }
        }
      }
    }

    _checkRoundEnd();
  }

  Vector2 _awayFromCenter(Vector2 pos) {
    final dir = pos - Vector2(_kRingCenterX, _kRingCenterY);
    return dir.length < 1 ? Vector2(1, 0) : dir.normalized();
  }

  void _eliminate(_SimPlayer sp) {
    if (!sp.alive) return;
    sp.alive = false;
    sp.fallAt = _elapsed;
    Audio.play('bomb.wav', volume: 0.6);
    // Clients get the new alive flag in the next snapshot.
  }

  void _checkRoundEnd() {
    final standing = _sim.where((p) => p.alive).toList();
    if (standing.length <= 1 || timeLeft <= 0) {
      finishRound();
    }
  }

  @override
  Map<String, dynamic> buildSnapshot() {
    return {
      'players': [
        for (final sp in _sim)
          {
            'id': sp.id,
            'x': sp.pos.x,
            'y': sp.pos.y,
            'alive': sp.alive,
          },
      ],
      'timeLeft': timeLeft,
    };
  }

  @override
  void applySnapshot(Map<String, dynamic> snap) {
    for (final raw in (snap['players'] as List<dynamic>? ?? [])) {
      final m = raw as Map<String, dynamic>;
      final sp = _byId[m['id']];
      if (sp == null) continue;
      sp.pos = Vector2((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
      sp.alive = m['alive'] as bool? ?? true;
    }
    timeLeft = (snap['timeLeft'] as num?)?.toDouble() ?? timeLeft;
  }

  @override
  List<PlacementResult> computeResults() {
    final players = activePlayers;
    final connectedIds = players.map((p) => p.id).toSet();
    final alive = _sim
        .where((p) => p.alive && connectedIds.contains(p.id))
        .map((p) => p.id)
        .toList();
    final eliminated = _sim
        .where((p) => !p.alive && connectedIds.contains(p.id))
        .toList()
      ..sort((a, b) => b.fallAt.compareTo(a.fallAt)); // later fall = better

    final tiers = <List<int>>[];
    if (alive.isNotEmpty) tiers.add(alive);
    // Eliminated players each get their own tier (latest out = best).
    for (final sp in eliminated) {
      tiers.add([sp.id]);
    }
    // Safety: if someone vanished entirely, rank them last.
    final rankedIds = tiers.expand((t) => t).toSet();
    final missing = players.map((p) => p.id).where((id) => !rankedIds.contains(id));
    for (final id in missing) {
      tiers.add([id]);
    }
    return tiedPoints(tiers);
  }
}

class _SumoLayer extends PositionComponent {
  _SumoLayer({required this.game});

  final SumoPushGame game;
  final Paint _rim = Paint()..color = const Color(0xff141419);
  final Paint _sand = Paint()..color = const Color(0xffd9b36c);
  final Paint _sandInner = Paint()..color = const Color(0xffcaa25a);
  final Paint _line = Paint()..color = const Color(0xff141419);
  final Paint _avatarPaint = Paint()..filterQuality = FilterQuality.none;

  @override
  void render(Canvas canvas) {
    // Backdrop: dark arena void + subtle floor.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kWorldW, kWorldH),
      Paint()..color = const Color(0xff101018),
    );
    // Floating platform: shadow, rim, sand.
    const center = Offset(_kRingCenterX, _kRingCenterY);
    canvas.drawCircle(center + const Offset(0, 10), _kRingRadius + 6,
        Paint()..color = const Color(0xff000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(center, _kRingRadius + 6, _rim);
    canvas.drawCircle(center, _kRingRadius, _sand);
    canvas.drawCircle(center, _kRingRadius - 26, _sandInner);
    canvas.drawCircle(
      center,
      _kRingRadius,
      _line
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
    _line.style = PaintingStyle.fill;
    // Center star motif.
    canvas.drawCircle(center, 12, Paint()..color = const Color(0xff141419));
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xffd9b36c));

    // Players.
    for (final sp in game._sim) {
      if (!sp.alive) continue;
      final image = game._avatars[sp.id];
      final name = _playerName(sp.id);
      if (image == null) continue;
      // Smooth render position toward logical position.
      sp.renderPos += (sp.pos - sp.renderPos) * 0.55;
      drawAvatar(canvas, image, sp.renderPos, 56, _avatarPaint);
      final tag = strokeText(size: 7, color: Colors.white);
      final w = textWidthOf(tag, name);
      tag.render(
        canvas,
        name,
        Vector2(sp.renderPos.x - w / 2, sp.renderPos.y - 46),
      );
    }
    // Dead players leave a small crater marker.
    for (final sp in game._sim) {
      if (sp.alive) continue;
      canvas.drawCircle(
        Offset(
          sp.renderPos.x.clamp(40, kWorldW - 40),
          sp.renderPos.y.clamp(60, kWorldH - 20),
        ),
        10,
        Paint()..color = const Color(0x66414119),
      );
    }
  }

  String _playerName(int id) {
    for (final p in game.roster) {
      if (p.id == id) return p.name.toUpperCase();
    }
    return 'P';
  }
}
