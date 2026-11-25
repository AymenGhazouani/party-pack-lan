import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import 'pixel_sprite.dart';

double _hueOf(Color c) {
  final maxC = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
  final minC = [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
  final delta = maxC - minC;
  if (delta == 0) return 0;
  double h;
  if (maxC == c.r) {
    h = 60 * (((c.g - c.b) / delta) % 6);
  } else if (maxC == c.g) {
    h = 60 * (((c.b - c.r) / delta) + 2);
  } else {
    h = 60 * (((c.r - c.g) / delta) + 4);
  }
  return h < 0 ? h + 360 : h;
}

Color shade(Color color, double deltaLightness) {
  final maxC = [color.r, color.g, color.b].reduce((a, b) => a > b ? a : b);
  final minC = [color.r, color.g, color.b].reduce((a, b) => a < b ? a : b);
  final lightness = (maxC + minC) / 2;
  final sat = maxC == minC
      ? 0.0
      : (maxC - minC) / (1 - (2 * lightness - 1).abs());
  return HSLColor.fromAHSL(1, _hueOf(color), sat.clamp(0.0, 1.0),
          (lightness + deltaLightness).clamp(0.0, 1.0))
      .toColor();
}

/// The 8 playable avatar body colors.
const List<Color> kAvatarColors = [
  Color(0xffef476f), // red
  Color(0xfff78c2b), // orange
  Color(0xffffd166), // yellow
  Color(0xff06d6a0), // green
  Color(0xff4cc9f0), // cyan
  Color(0xff5a8dee), // blue
  Color(0xff9d6df5), // purple
  Color(0xfff72585), // magenta
];

const _avatarGrid = [
  '...llll...',
  '..llllll..',
  '.llllllll.',
  'llmmmmmmll',
  'mmssssssmm',
  'mmssssssmm',
  'mmmmmmmmmm',
  'mmmmmmmmmm',
  'mmmmmmmmmm',
  'mm.mmmm.mm',
  'mm.mmmm.mm',
  '.mmmmmmmm.',
  '..dd..dd..',
  '.ddd..ddd.',
];

PixelSprite avatarSprite(int avatarId) {
  final base = kAvatarColors[avatarId % kAvatarColors.length];
  return PixelSprite(_avatarGrid, {
    'l': shade(base, 0.22),
    'm': base,
    'd': shade(base, -0.22),
    's': const Color(0xff1b1b24),
    '.': null,
  });
}

PixelSprite gemSprite(Color base) => PixelSprite(
      const [
        '.llggll.',
        'lggggggl',
        'gggggggg',
        'dggggggd',
        '.dddddd.',
        '..dddd..',
      ],
      {
        'l': shade(base, 0.35),
        'g': base,
        'd': shade(base, -0.25),
        '.': null,
      },
    );

final gemEmerald = gemSprite(const Color(0xff2ee6a8));
final gemRuby = gemSprite(const Color(0xffff5d73));
final gemSapphire = gemSprite(const Color(0xff54a8ff));

final bombSprite = PixelSprite(
  const [
    '...y....',
    '........',
    '...##...',
    '########',
    '#h#####d',
    '#######d',
    '.######.',
  ],
  {
    'y': const Color(0xffffe066),
    '#': const Color(0xff2b2b33),
    'h': const Color(0xff7a7a88),
    'd': const Color(0xff17171d),
    '.': null,
  },
);

final emberSprite = PixelSprite(
  const [
    '..o..',
    '.ooo.',
    'oyyyo',
    'oywyo',
    '.ooo.',
  ],
  {
    'o': const Color(0xffff8c1a),
    'y': const Color(0xffffd23f),
    'w': const Color(0xfffff6d8),
    '.': null,
  },
);

final sparkSprite = PixelSprite(
  const [
    '..w..',
    '.www.',
    'wwwww',
    '.www.',
    '..w..',
  ],
  {
    'w': const Color(0xffffffff),
    '.': null,
  },
);

final crownSprite = PixelSprite(
  const [
    'y..y..y',
    'yyy.yyy',
    'yyyyyyy',
    'yyyyyyy',
    'yryyyry',
  ],
  {
    'y': const Color(0xffd4a017),
    'r': const Color(0xfffff3b0),
    '.': null,
  },
);
