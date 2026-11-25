import 'dart:math';

import 'package:flutter/material.dart';

/// Seeded starfield + mountains backdrop used behind menu screens.
class StarfieldPainter extends CustomPainter {
  const StarfieldPainter({this.seed = 1337});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xff12121f), Color(0xff1d1830), Color(0xff241a36)],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = gradient.createShader(Offset.zero & size));

    final rnd = Random(seed);
    // Stars in the upper ~65% of the screen.
    final starPaint = Paint();
    for (var i = 0; i < 110; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.62;
      final s = rnd.nextDouble();
      final px = s < 0.7 ? 2.0 : (s < 0.92 ? 3.0 : 4.0);
      starPaint.color = switch (rnd.nextInt(4)) {
        0 => const Color(0xffffffff),
        1 => const Color(0xffffd166),
        2 => const Color(0xff4cc9f0),
        _ => const Color(0xffe3e3f1),
      };
      canvas.drawRect(Rect.fromLTWH(x, y, px, px), starPaint);
    }

    // Big pixel moon.
    final moon = Paint()..color = const Color(0xfff5e9c8);
    final mx = size.width * 0.78;
    final my = size.height * 0.2;
    canvas.drawRect(Rect.fromLTWH(mx - 26, my - 30, 52, 60), moon);
    canvas.drawRect(Rect.fromLTWH(mx - 34, my - 20, 68, 40), moon);
    canvas.drawRect(Rect.fromLTWH(mx - 20, my - 36, 40, 72), moon);
    final crater = Paint()..color = const Color(0xffd9cba0);
    canvas.drawRect(Rect.fromLTWH(mx - 12, my - 8, 10, 10), crater);
    canvas.drawRect(Rect.fromLTWH(mx + 8, my + 6, 8, 8), crater);

    // Mountain silhouettes.
    final ridgeFar = Paint()..color = const Color(0xff1c1c2e);
    final ridgeNear = Paint()..color = const Color(0xff141419);
    final horizon = size.height * 0.78;
    canvas.drawPath(_ridge(rnd, size.width, horizon, 90, 0.55), ridgeFar);
    canvas.drawPath(_ridge(rnd, size.width, horizon + 26, 130, 0.8), ridgeNear);

    // Ground.
    canvas.drawRect(
      Rect.fromLTWH(0, horizon + 40, size.width, size.height - horizon),
      ridgeNear,
    );
  }

  Path _ridge(Random rnd, double width, double baseY, double height, double rough) {
    final path = Path()..moveTo(-20, baseY + 200);
    var x = -20.0;
    path.lineTo(x, baseY);
    while (x < width + 20) {
      final peakW = 60 + rnd.nextDouble() * 120 * rough;
      final peakH = height * (0.35 + rnd.nextDouble() * 0.65);
      path.lineTo(x + peakW / 2, baseY - peakH);
      path.lineTo(x + peakW, baseY);
      x += peakW;
    }
    path.lineTo(width + 40, baseY + 200);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) => false;
}

/// Simple animated confetti rain painted as pixel squares.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.t});

  final double t; // 0..1 loop

  static const _colors = [
    Color(0xffffd166),
    Color(0xff4cc9f0),
    Color(0xff06d6a0),
    Color(0xffef476f),
    Color(0xff9d6df5),
    Color(0xfff78c2b),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(77);
    final paint = Paint();
    for (var i = 0; i < 70; i++) {
      final speed = 0.35 + rnd.nextDouble() * 0.5;
      final sway = 18 + rnd.nextDouble() * 30;
      final startX = rnd.nextDouble() * size.width;
      final drop = (t * speed * 6 + rnd.nextDouble()) % 1.2;
      final y = drop * size.height;
      final x = startX + sin((t * 4 + i) * 2) * sway * 0.4;
      final s = 4.0 + rnd.nextDouble() * 6;
      paint.color = _colors[i % _colors.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(((i * 37) % 10) / 10 * pi);
      canvas.drawRect(Rect.fromLTWH(-s / 2, -s / 2, s, s * 0.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
