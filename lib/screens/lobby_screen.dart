import 'package:flutter/material.dart';

import '../game/game_registry.dart';
import '../model/models.dart';
import '../state/app_controller.dart';
import '../ui/avatar_view.dart';
import '../ui/backdrops.dart';
import '../ui/confirm_dialog.dart';
import '../ui/pixel_widgets.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key, required this.app});

  final AppController app;

  Future<void> _leave(BuildContext context) async {
    final confirm = await showConfirmDialog(
      context,
      title: app.amHost ? 'END SESSION?' : 'LEAVE LOBBY?',
      message: app.amHost
          ? 'THIS WILL KICK EVERYONE FROM THE GAME.'
          : 'YOU CAN JOIN AGAIN ANY TIME.',
      confirmLabel: 'LEAVE',
      danger: true,
    );
    if (confirm) app.leaveToMenu();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: StarfieldPainter()),
              ),
              Positioned.fill(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(18, 10, 18, 10),
                  child: Row(
                    children: [
                      // Players list
                      Expanded(
                        flex: 5,
                        child: PixelPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const PixelLabel('PLAYERS',
                                      size: 11,
                                      color: Color(0xff4cc9f0)),
                                  const Spacer(),
                                  PixelLabel(
                                    '${app.players.where((p) => p.connected).length}/4',
                                    size: 10,
                                    color: const Color(0xffffd166),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final p in app.players)
                                _PlayerRow(player: p, isMe: p.id == app.myPlayerId),
                              if (app.amHost) ...[
                                const Spacer(),
                                const PixelLabel('HOST JOIN CODE (IP)',
                                    size: 7, color: Color(0xff777788)),
                                const SizedBox(height: 4),
                                SelectableText(
                                  app.hostIp,
                                  style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 12,
                                    color: Color(0xff06d6a0),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                PixelButton(
                                  label: 'END SESSION',
                                  face: const Color(0xff3f3f58),
                                  textColor: Colors.white,
                                  fontSize: 10,
                                  expand: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  onTap: () => _leave(context),
                                ),
                              ] else ...[
                                const Spacer(),
                                PixelButton(
                                  label: 'LEAVE LOBBY',
                                  face: const Color(0xff3f3f58),
                                  textColor: Colors.white,
                                  fontSize: 10,
                                  expand: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  onTap: () => _leave(context),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Host controls
                      Expanded(
                        flex: 7,
                        child: PixelPanel(
                          color: const Color(0xff232338),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const PixelLabel('ROUND SETTINGS',
                                      size: 11,
                                      color: Color(0xffffd166)),
                                  const Spacer(),
                                  _RoundBadge(
                                      round: app.round,
                                      total: app.totalRounds),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final r in [2, 4, 6, 8])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _ChoiceChip(
                                        label: '$r',
                                        selected: app.totalRounds == r,
                                        enabled: app.amHost,
                                        onTap: () => app.setTotalRounds(r),
                                      ),
                                    ),
                                  const PixelLabel('ROUNDS',
                                      size: 8,
                                      color: Color(0xff777788)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const PixelLabel('NEXT GAME',
                                  size: 11, color: Color(0xffffd166)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: GridView(
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 2.6,
                                  ),
                                  children: [
                                    for (final g in kGames)
                                      _GameCard(
                                        game: g,
                                        selected: app.selectedGameId == g.id,
                                        enabled: app.amHost,
                                        onTap: () => app.selectGame(
                                          app.selectedGameId == g.id ? null : g.id,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _RandomChip(
                                selected: app.selectedGameId == null,
                                enabled: app.amHost,
                                onTap: () => app.selectGame(null),
                              ),
                              const SizedBox(height: 12),
                              if (app.amHost)
                                _StartButton(app: app)
                              else
                                const _WaitingForHost(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player, required this.isMe});

  final PlayerInfo player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final connected = player.connected;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xff2e2e44) : const Color(0xff20202f),
        border: Border.all(
          color: isMe ? const Color(0xffffd166) : const Color(0xff141419),
          width: 3,
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: connected ? 1 : 0.3,
            child: AvatarView(avatarId: player.avatarId, scale: 3),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelLabel(
                  player.name.toUpperCase(),
                  size: 10,
                  color: connected ? Colors.white : const Color(0xff555566),
                ),
                if (!connected)
                  const PixelLabel('LEFT THE GAME',
                      size: 6, color: Color(0xffef476f)),
              ],
            ),
          ),
          if (player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: const Color(0xffffd166),
              child: const PixelLabel('HOST',
                  size: 7, color: Color(0xff141419)),
            )
          else
            PixelLabel('${player.totalScore} PTS',
                size: 8, color: const Color(0xff9a9aa8)),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  const _RoundBadge({required this.round, required this.total});

  final int round;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xff141419),
        border: Border.all(color: const Color(0xffffd166), width: 2),
      ),
      child: PixelLabel('ROUND $round/$total',
          size: 8, color: const Color(0xffffd166)),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xffffd166)
              : const Color(0xff2e2e44),
          border: Border.all(color: const Color(0xff141419), width: 3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: selected ? const Color(0xff141419) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final GameInfo game;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xff3a3517) : const Color(0xff2e2e44),
          border: Border.all(
            color:
                selected ? const Color(0xffffd166) : const Color(0xff141419),
            width: 3,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PixelLabel(game.title,
                      size: 8,
                      color: selected
                          ? const Color(0xffffd166)
                          : Colors.white),
                  const SizedBox(height: 5),
                  PixelLabel(game.subtitle.toUpperCase(),
                      size: 5, color: const Color(0xff9a9aa8)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: switch (game.mode) {
                GameMode.ffa => const Color(0xffef476f),
                GameMode.teams => const Color(0xff4cc9f0),
                GameMode.coop => const Color(0xff06d6a0),
              },
              child: PixelLabel(modeTag(game.mode),
                  size: 6, color: const Color(0xff141419)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RandomChip extends StatelessWidget {
  const _RandomChip({
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xff3a3517) : const Color(0xff1d1d2b),
          border: Border.all(
            color: selected
                ? const Color(0xffffd166)
                : const Color(0xff2e2e44),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: PixelLabel(
          'RANDOM',
          size: 9,
          color: selected ? const Color(0xffffd166) : const Color(0xff9a9aa8),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    final picked = app.selectedGameId == null
        ? 'RANDOM'
        : gameById(app.selectedGameId!)!.title;
    return PixelButton(
      label: 'START: $picked',
      face: const Color(0xff06d6a0),
      fontSize: 13,
      expand: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      onTap: app.startRound,
    );
  }
}

class _WaitingForHost extends StatelessWidget {
  const _WaitingForHost();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xff1d1d2b),
        border: Border.all(color: const Color(0xff2e2e44), width: 2),
      ),
      child: const PixelLabel('WAITING FOR HOST…',
          size: 10, color: Color(0xff777788)),
    );
  }
}
