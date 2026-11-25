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

const double _kBasketY = 462;
const double _kCatchHalfWidth = 56;
const double _kPlayerSpeed = 380;

class _Item {
  _Item(this.id, this.kind, this.value, this.x, this.y, this.vy, this.sway);

  final int id;
  final String kind; // 'emerald' | 'ruby' | 'sapphire' | 'bomb'
  final int value;
  double x, y, vy;
  final double sway;
  double phase = 0;
}

class _Catcher {
  _Catcher(this.id);

  final int id;
  double x = kWorldW / 2;
  double renderX = kWorldW / 2;
  int count = 0;
  double flashT = 0; // red flash on bomb hit
  Vector2 vel = Vector2.zero();
}

class GemCatchGame extends PartyGame {
  GemCatchGame({
    required super.session,
    required super.roster,
    required super.round,
    required super.totalRounds,
    required super.gameInfo,
    required super.onRoundFinish,
  });

  final List<_Item> _items = [];
  final Map<int, _Catcher> _players = {};
  final Map<int, ui.Image> _avatars = {};
  ui.Image? _emerald;
  ui.Image? _ruby;
  ui.Image? _sapphire;
  ui.Image? _bomb;

  double _spawnTimer = 0;
  int _itemSeq = 0;
  double _elapsed = 0;
  final math.Random _rng = math.Random();

  // Precomputed skyline (both sides render the same seed).
  final List<_Building> _skyline = [];
  List<_Star> _stars = [];

  @override
  FutureOr<void> onGameLoad() async {
    timeLeft = 45;
    final players = activePlayers;
    final n = players.length;
    for (var i = 0; i < n; i++) {
      final p = players[i];
      _players[p.id] = _Catcher(p.id)
        ..x = kWorldW * (i + 1) / (n + 1)
        ..renderX = kWorldW * (i + 1) / (n + 1);
      _avatars[p.id] = await avatarSprite(p.avatarId).imageAt(4);
    }
    _emerald = await gemEmerald.imageAt(3);
    _ruby = await gemRuby.imageAt(3);
    _sapphire = await gemSapphire.imageAt(3);
    _bomb = await bombSprite.imageAt(3);
    _buildSkyline();
    world.add(_GemLayer(game: this));
  }

  void _buildSkyline() {
    final rnd = math.Random(20260601);
    var x = -10.0;
    while (x < kWorldW + 20) {
      final w = 34 + rnd.nextDouble() * 70;
      final h = 40 + rnd.nextDouble() * 110;
      final windows = <_Window>[];
      final cols = (w / 14).floor();
      final rows = (h / 18).floor();
      for (var c = 0; c < cols; c++) {
        for (var r = 0; r < rows; r++) {
          if (rnd.nextDouble() < 0.32) {
            windows.add(_Window(8.0 + c * 14, 10.0 + r * 18));
          }
        }
      }
      _skyline.add(_Building(x, kWorldH - 92, w, h, windows));
      x += w + 6 + rnd.nextDouble() * 26;
    }
    _stars = [
      for (var i = 0; i < 90; i++)
        _Star(rnd.nextDouble() * kWorldW, rnd.nextDouble() * 260,
            rnd.nextDouble() * 2 + 1),
    ];
  }

  @override
  void simulate(double dt) {
    _elapsed += dt;
    final players = activePlayers;

    // Movement (horizontal only).
    for (final p in players) {
      final c = _players[p.id]!;
      final input = inputFor(p.id);
      final dir = input.x;
      const accel = 2600.0;
      c.vel.x += dir * accel * dt;
      c.vel.x *= math.max(0.0, 1 - 6.5 * dt);
      if (c.vel.x.abs() > _kPlayerSpeed) {
        c.vel.x = _kPlayerSpeed * c.vel.x.sign;
      }
      c.x = (c.x + c.vel.x * dt).clamp(50.0, kWorldW - 50.0);
      c.renderX = c.x;
      c.flashT = math.max(0, c.flashT - dt);
    }

    // Spawning (ramps up slightly over time).
    _spawnTimer += dt;
    final interval = math.max(0.42, 0.78 - _elapsed * 0.006);
    if (_spawnTimer >= interval) {
      _spawnTimer = 0;
      final roll = _rng.nextDouble();
      String kind;
      int value;
      if (roll < 0.24) {
        kind = 'bomb';
        value = -2;
      } else {
        final g = _rng.nextDouble();
        if (g < 0.55) {
          kind = 'emerald';
          value = 1;
        } else if (g < 0.85) {
          kind = 'ruby';
          value = 2;
        } else {
          kind = 'sapphire';
          value = 3;
        }
      }
      _items.add(_Item(
        _itemSeq++,
        kind,
        value,
        60 + _rng.nextDouble() * (kWorldW - 120),
        40,
        215 + _elapsed * 2.2 + _rng.nextDouble() * 70,
        26 + _rng.nextDouble() * 30,
      ));
    }

    // Item motion + catching.
    final caught = <_Item>[];
    for (final item in _items) {
      item.phase += dt * 2.1;
      item.y += item.vy * dt;
      item.x += math.sin(item.phase) * item.sway * dt;

      if (item.y >= _kBasketY - 22 && item.y <= _kBasketY + 12) {
        for (final p in players) {
          final c = _players[p.id]!;
          if ((item.x - c.x).abs() <= _kCatchHalfWidth) {
            c.count += item.value;
            if (item.value < 0) {
              c.flashT = 0.6;
              Audio.bomb();
            } else {
              Audio.gem();
            }
            caught.add(item);
            break;
          }
        }
      }
      if (item.y > kWorldH + 40) caught.add(item);
    }
    _items.removeWhere(caught.contains);

    if (timeLeft <= 0) finishRound();
  }

  @override
  Map<String, dynamic> buildSnapshot() => {
        'items': [
          for (final item in _items)
            {
              'id': item.id,
              'kind': item.kind,
              'x': item.x,
              'y': item.y,
            },
        ],
        'players': [
          for (final entry in _players.entries)
            {
              'id': entry.key,
              'x': entry.value.x,
              'n': entry.value.count,
              'flash': entry.value.flashT > 0,
            },
        ],
        'timeLeft': timeLeft,
      };

  @override
  void applySnapshot(Map<String, dynamic> snap) {
    _items
      ..clear()
      ..addAll([
        for (final raw in (snap['items'] as List<dynamic>? ?? []))
          _Item(
            (raw as Map<String, dynamic>)['id'] as int,
            raw['kind'] as String,
            0,
            (raw['x'] as num).toDouble(),
            (raw['y'] as num).toDouble(),
            0,
            0,
          ),
      ]);
    for (final raw in (snap['players'] as List<dynamic>? ?? [])) {
      final m = raw as Map<String, dynamic>;
      final c = _players[m['id']];
      if (c == null) continue;
      c.x = (m['x'] as num).toDouble();
      c.count = m['n'] as int? ?? 0;
      c.flashT = (m['flash'] as bool? ?? false) ? 0.5 : 0;
    }
    timeLeft = (snap['timeLeft'] as num?)?.toDouble() ?? timeLeft;
  }

  @override
  List<PlacementResult> computeResults() {
    final connectedIds = activePlayers.map((p) => p.id).toSet();
    // Rank by catch count, ties share placements. Disconnected players
    // score 0 for the round.
    final entries = _players.values
        .where((p) => connectedIds.contains(p.id))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    final tiers = <List<int>>[];
    var i = 0;
    while (i < entries.length) {
      var j = i + 1;
      while (j < entries.length && entries[j].count == entries[i].count) {
        j++;
      }
      tiers.add([for (var k = i; k < j; k++) entries[k].id]);
      i = j;
    }
    return tiedPoints(tiers);
  }
}

class _Building {
  const _Building(this.x, this.y, this.w, this.h, this.windows);
  final double x, y, w, h;
  final List<_Window> windows;
}

class _Window {
  const _Window(this.dx, this.dy);
  final double dx, dy;
}

class _Star {
  const _Star(this.x, this.y, this.size);
  final double x, y, size;
}

class _GemLayer extends PositionComponent {
  _GemLayer({required this.game});

  final GemCatchGame game;
  final Paint _avatarPaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _emeraldGlow = Paint()..color = const Color(0x332ee6a8);
  final Paint _rubyGlow = Paint()..color = const Color(0x33ff5d73);
  final Paint _sapphireGlow = Paint()..color = const Color(0x3354a8ff);
  final Paint _bombGlow = Paint()..color = const Color(0x22ffffff);

  @override
  void render(Canvas canvas) {
    // Night sky gradient.
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xff0d1024), Color(0xff1d1b3a), Color(0xff2c2138)],
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kWorldW, kWorldH),
      Paint()..shader = gradient.createShader(const Rect.fromLTWH(0, 0, kWorldW, kWorldH)),
    );
    // Stars + moon.
    final starPaint = Paint()..color = const Color(0xffffffff);
    for (final s in game._stars) {
      starPaint.color = Color.fromARGB(230, 255, 255, 255);
      canvas.drawRect(Rect.fromLTWH(s.x, s.y, s.size, s.size), starPaint);
    }
    canvas.drawCircle(const Offset(838, 74), 34, Paint()..color = const Color(0xfff5e9c8));
    canvas.drawCircle(const Offset(838, 74), 34,
        Paint()..color = const Color(0xff141419)..style = PaintingStyle.stroke..strokeWidth = 3);

    // Skyline silhouette.
    final buildingPaint = Paint()..color = const Color(0xff141424);
    final litPaint = Paint()..color = const Color(0xffffdf8a);
    for (final b in game._skyline) {
      canvas.drawRect(Rect.fromLTWH(b.x, b.y - b.h, b.w, b.h), buildingPaint);
      for (final w in b.windows) {
        canvas.drawRect(Rect.fromLTWH(b.x + w.dx, b.y - b.h + w.dy, 6, 8), litPaint);
      }
    }
    // Ground strip.
    canvas.drawRect(
      const Rect.fromLTWH(0, kWorldH - 92, kWorldW, 92),
      Paint()..color = const Color(0xff101018),
    );

    // Catch zone hint line.
    final zonePaint = Paint()
      ..color = const Color(0x224cc9f0)
      ..strokeWidth = 2;
    for (var x = 0.0; x < kWorldW; x += 24) {
      canvas.drawLine(Offset(x, _kBasketY), Offset(x + 10, _kBasketY), zonePaint);
    }

    // Items.
    for (final item in game._items) {
      final (img, glow) = switch (item.kind) {
        'emerald' => (game._emerald, _emeraldGlow),
        'ruby' => (game._ruby, _rubyGlow),
        'sapphire' => (game._sapphire, _sapphireGlow),
        _ => (game._bomb, _bombGlow),
      };
      canvas.drawCircle(Offset(item.x, item.y), 22, glow);
      if (img != null) {
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromCenter(center: Offset(item.x, item.y), width: 40, height: 40 * img.height / img.width),
          _avatarPaint,
        );
      }
    }

    // Players + baskets.
    for (final entry in game._players.entries) {
      final c = entry.value;
      c.renderX += (c.x - c.renderX) * 0.5;
      final px = isHostSide(game) ? c.x : c.renderX;
      _drawCatcher(canvas, entry.key, px, c);
    }

    // Score chips.
    _drawScoreChips(canvas);
  }

  bool isHostSide(GemCatchGame game) => game.isHost;

  void _drawCatcher(Canvas canvas, int id, double x, _Catcher c) {
    final avatar = game._avatars[id];
    final flash = c.flashT > 0;
    final teamColor =
        kAvatarColors[game.roster.firstWhere((p) => p.id == id, orElse: () => game.roster.first).avatarId % kAvatarColors.length];

    // Basket back panel.
    final basketPaint = Paint()
      ..color = flash ? const Color(0xffef476f) : teamColor;
    final path = Path()
      ..moveTo(x - 52, _kBasketY - 6)
      ..lineTo(x + 52, _kBasketY - 6)
      ..lineTo(x + 38, _kBasketY + 42)
      ..lineTo(x - 38, _kBasketY + 42)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xff141419));
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(path, basketPaint);
    canvas.restore();

    // Avatar peeking out of the basket? Place sprite above it.
    if (avatar != null) {
      drawAvatar(canvas, avatar, Vector2(x, _kBasketY - 24), 44, _avatarPaint);
      if (flash) {
        canvas.drawCircle(
          Offset(x, _kBasketY - 24),
          30,
          Paint()..color = const Color(0x66ef476f),
        );
      }
    }

    final name = _playerName(id);
    final tag = strokeText(size: 7, color: Colors.white);
    final w = textWidthOf(tag, name);
    tag.render(canvas, name, Vector2(x - w / 2, _kBasketY + 46));
  }

  void _drawScoreChips(Canvas canvas) {
    var x = 14.0;
    final chipBg = Paint()..color = const Color(0x88141419);
    for (final entry in game._players.entries) {
      final id = entry.key;
      final n = entry.value.count;
      final label = '×$n';
      final text = strokeText(size: 9, color: Colors.white);
      final w = textWidthOf(text, label);
      canvas.drawRect(Rect.fromLTWH(x, 44, w + 34, 20), chipBg);
      // Mini avatar dot: use avatar image scaled tiny.
      final avatar = game._avatars[id];
      if (avatar != null) {
        canvas.drawImageRect(
          avatar,
          Rect.fromLTWH(0, 0, avatar.width.toDouble(), avatar.height.toDouble()),
          Rect.fromLTWH(x + 2, 45, 16, 17),
          _avatarPaint,
        );
      }
      text.render(canvas, label, Vector2(x + 22, 47));
      x += w + 44;
    }
  }

  String _playerName(int id) {
    for (final p in game.roster) {
      if (p.id == id) return p.name.toUpperCase();
    }
    return 'P';
  }
}
