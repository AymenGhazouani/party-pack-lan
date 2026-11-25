import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// A pixel-art sprite defined as rows of characters mapped through a palette.
///
/// Sprites are rasterized once (cached) at a chosen scale and drawn with
/// nearest-neighbor filtering so pixels stay crisp at any size.
class PixelSprite {
  PixelSprite(this.grid, this.palette)
      : assert(grid.isNotEmpty, 'grid must not be empty');

  /// Rows of characters; '.' (or any char mapped to null) is transparent.
  final List<String> grid;
  final Map<String, Color?> palette;

  int get columns => grid.fold(0, (m, r) => r.length > m ? r.length : m);
  int get rows => grid.length;

  final Map<int, ui.Image> _cache = {};

  /// Rasterize (or fetch cached) renderable image at [scale] pixels per cell.
  Future<ui.Image> imageAt(int scale) async {
    final cached = _cache[scale];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        final color = palette[row[x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
              x * scale.toDouble(), y * scale.toDouble(),
              scale.toDouble(), scale.toDouble()),
          paint,
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(columns * scale, rows * scale);
    _cache[scale] = image;
    return image;
  }

  ui.Image? cachedImageAt(int scale) => _cache[scale];

  /// Draw directly (vector fallback) — used for painting into canvases that
  /// want crisp rects rather than the cached image.
  void paintCells(Canvas canvas, Rect dst) {
    final cw = dst.width / columns;
    final ch = dst.height / rows;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (var x = 0; x < row.length; x++) {
        final color = palette[row[x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(
              dst.left + x * cw, dst.top + y * ch, cw + 0.5, ch + 0.5),
          paint,
        );
      }
    }
  }
}

/// CustomPainter that draws a [PixelSprite] scaled to [size], pixel-perfect.
class PixelSpritePainter extends CustomPainter {
  const PixelSpritePainter(this.sprite, {this.flip = false});

  final PixelSprite sprite;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    sprite.paintCells(canvas, Offset.zero & size);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PixelSpritePainter oldDelegate) =>
      oldDelegate.sprite != sprite || oldDelegate.flip != flip;
}

/// Flutter widget rendering a sprite with nearest-neighbor pixels.
class PixelSpriteImage extends StatelessWidget {
  const PixelSpriteImage(
    this.sprite, {
    super.key,
    this.width,
    this.height,
    this.flip = false,
    this.scale = 4,
  });

  final PixelSprite sprite;
  final double? width;
  final double? height;
  final bool flip;
  final int scale;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(
        width ?? sprite.columns * scale.toDouble(),
        height ?? sprite.rows * scale.toDouble(),
      ),
      painter: PixelSpritePainter(sprite, flip: flip),
    );
  }
}
