import 'package:flutter/material.dart';

import '../../pixel/pixel_sprite.dart';
import '../../pixel/sprites.dart';

/// Avatar sprite sized by pixel scale.
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.avatarId,
    this.scale = 5,
    this.flip = false,
  });

  final int avatarId;
  final int scale;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return PixelSpriteImage(avatarSprite(avatarId), scale: scale, flip: flip);
  }
}
