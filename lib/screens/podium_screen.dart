import 'package:flutter/material.dart';

import '../model/models.dart';
import '../pixel/pixel_sprite.dart';
import '../pixel/sprites.dart';
import '../state/app_controller.dart';
import '../ui/avatar_view.dart';
import '../ui/backdrops.dart';
import '../ui/pixel_widgets.dart';

class PodiumScreen extends StatefulWidget {
  const PodiumScreen({super.key, required this.app});

  final AppController app;

  @override
  State<PodiumScreen> createState() => _PodiumScreenState();
}

class _PodiumScreenState extends State<PodiumScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final podium = app.podiumOrder;
        final first = podium.isNotEmpty ? podium[0] : null;
        final second = podium.length > 1 ? podium[1] : null;
        final third = podium.length > 2 ? podium[2] : null;

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: StarfieldPainter()),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: ConfettiPainter(t: _confetti.value),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  const PixelLabel('FINAL RESULTS',
                      size: 16, color: Color(0xffffd166)),
                  const SizedBox(height: 4),
                  if (first != null)
                    PixelLabel(
                      '${first.name.toUpperCase()} TAKES THE CROWN!',
                      size: 9,
                      color: const Color(0xff4cc9f0),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (second != null)
                        _PodiumBlock(player: second, place: 2, height: 96),
                      const SizedBox(width: 14),
                      if (first != null)
                        _PodiumBlock(player: first, place: 1, height: 160),
                      const SizedBox(width: 14),
                      if (third != null)
                        _PodiumBlock(player: third, place: 3, height: 64),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 4th place (if any) listed underneath.
                  if (podium.length > 3)
                    PixelPanel(
                      color: const Color(0xff20202f),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PixelLabel('#4', size: 9,
                              color: Color(0xff9a9aa8)),
                          const SizedBox(width: 10),
                          PixelLabel(
                            '${podium[3].name.toUpperCase()}  •  ${podium[3].totalScore} PTS',
                            size: 8,
                            color: const Color(0xffc9c9d6),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (app.amHost)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PixelButton(
                          label: 'PLAY AGAIN',
                          face: const Color(0xff06d6a0),
                          fontSize: 14,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 34, vertical: 16),
                          onTap: app.playAgain,
                        ),
                        const SizedBox(width: 14),
                        PixelButton(
                          label: 'MAIN MENU',
                          face: const Color(0xff3f3f58),
                          textColor: Colors.white,
                          fontSize: 14,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 34, vertical: 16),
                          onTap: app.leaveToMenu,
                        ),
                      ],
                    )
                  else
                    const PixelLabel('WAITING FOR HOST…',
                        size: 10, color: Color(0xff777788)),
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.player,
    required this.place,
    required this.height,
  });

  final PlayerInfo player;
  final int place;
  final double height;

  @override
  Widget build(BuildContext context) {
    final blockColor = switch (place) {
      1 => const Color(0xffd4a017),
      2 => const Color(0xff8f8f9e),
      _ => const Color(0xffa06a2c),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (place == 1)
          PixelSpriteImage(crownSprite, width: 44, height: 32),
        AvatarView(avatarId: player.avatarId, scale: place == 1 ? 6 : 4),
        const SizedBox(height: 2),
        PixelLabel(player.name.toUpperCase(),
            size: place == 1 ? 9 : 8, color: Colors.white),
        const SizedBox(height: 2),
        PixelLabel('${player.totalScore} PTS',
            size: 8, color: const Color(0xffffd166)),
        const SizedBox(height: 6),
        Container(
          width: 120,
          height: height,
          decoration: BoxDecoration(
            color: blockColor,
            border: Border.all(color: const Color(0xff141419), width: 3),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: PixelLabel('#$place',
              size: 16, color: const Color(0xff141419)),
        ),
      ],
    );
  }
}
