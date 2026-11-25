import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/fire_brigade/fire_brigade_game.dart';
import '../game/game_registry.dart';
import '../game/gem_catch/gem_catch_game.dart';
import '../game/party_game.dart';
import '../game/sumo_push/sumo_push_game.dart';
import '../game/tug_of_war/tug_of_war_game.dart';
import '../model/models.dart';
import '../state/app_controller.dart';
import '../state/input_bus.dart';
import '../ui/confirm_dialog.dart';
import '../ui/pixel_widgets.dart';
import '../ui/touch_controls.dart';

/// Creates [PartyGame] for the current app session.
PartyGame buildPartyGame(AppController app) {
  final session = app.session!;
  final roster = List<PlayerInfo>.from(app.players);
  final gameInfo = app.activeGame!;
  final round = app.round;
  final totalRounds = app.totalRounds;
  void onRoundFinish(List<PlacementResult> results, bool coOpSuccess) {
    app.finishRound(
      gameId: gameInfo.id,
      results: results,
      coOpSuccess: coOpSuccess,
    );
  }

  switch (gameInfo.id) {
    case 'sumo_push':
      return SumoPushGame(
        session: session,
        roster: roster,
        round: round,
        totalRounds: totalRounds,
        gameInfo: gameInfo,
        onRoundFinish: onRoundFinish,
      );
    case 'tug_of_war':
      return TugOfWarGame(
        session: session,
        roster: roster,
        round: round,
        totalRounds: totalRounds,
        gameInfo: gameInfo,
        onRoundFinish: onRoundFinish,
      );
    case 'gem_catch':
      return GemCatchGame(
        session: session,
        roster: roster,
        round: round,
        totalRounds: totalRounds,
        gameInfo: gameInfo,
        onRoundFinish: onRoundFinish,
      );
    case 'fire_brigade':
      return FireBrigadeGame(
        session: session,
        roster: roster,
        round: round,
        totalRounds: totalRounds,
        gameInfo: gameInfo,
        onRoundFinish: onRoundFinish,
      );
    default:
      throw StateError('Unknown game ${gameInfo.id}');
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.app});

  final AppController app;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PartyGame? _game;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _game = buildPartyGame(widget.app);
    } catch (e) {
      _error = '$e';
    }
  }

  @override
  void dispose() {
    widget.app.session?.unhook();
    inputBus.reset();
    super.dispose();
  }

  Future<void> _leave(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: widget.app.amHost ? 'END GAME?' : 'LEAVE GAME?',
      message: widget.app.amHost
          ? 'EVERYONE GETS KICKED TO THE MENU.'
          : 'YOU WILL RETURN TO THE MENU.',
      confirmLabel: 'LEAVE',
      danger: true,
    );
    if (ok) widget.app.leaveToMenu();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final game = _game;
    final info = app.activeGame;
    if (game == null || info == null) {
      return Scaffold(
        backgroundColor: const Color(0xff16161e),
        body: Center(
          child: PixelLabel(_error ?? 'COULD NOT START GAME',
              size: 10, color: const Color(0xffef476f)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xff101018),
      body: Stack(
        children: [
          Positioned.fill(
            child: GameWidget(game: game),
          ),
          // Leave button (top-right)
          Positioned(
            right: 10,
            top: 46,
            child: Opacity(
              opacity: 0.75,
              child: GestureDetector(
                onTap: () => _leave(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xff2e2e44),
                    border: Border.all(color: const Color(0xff141419), width: 2),
                  ),
                  child: const Icon(Icons.close,
                      color: Color(0xffcfd2dc), size: 20),
                ),
              ),
            ),
          ),
          // Touch controls
          if (info.controls.needsJoystick)
            Positioned(
              left: 18,
              bottom: 18,
              child: Joystick(
                size: 128,
                lockX: info.controls.axis == JoystickAxis.x,
              ),
            ),
          if (info.controls.dash)
            Positioned(
              right: 20,
              bottom: 30,
              child: ActionHoldButton(
                label: 'DASH',
                face: const Color(0xffffd166),
                size: 92,
                onDown: () => inputBus.setDash(true),
                onUp: () => inputBus.setDash(false),
              ),
            ),
          if (info.controls.actionLabel != null)
            Positioned(
              right: 20,
              bottom: 30,
              child: ActionHoldButton(
                label: info.controls.actionLabel!,
                face: const Color(0xff4cc9f0),
                size: 104,
                onDown: () => inputBus.setAction(true),
                onUp: () => inputBus.setAction(false),
              ),
            ),
          if (info.controls.mash)
            const Positioned(
              right: 34,
              bottom: 24,
              child: MashButton(),
            ),
          // Countdown overlay
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<int>(
                valueListenable: game.countdown,
                builder: (context, value, _) {
                  if (value <= 0) return const SizedBox.shrink();
                  return _CountdownOverlay(
                    value: value,
                    goal: info.goal,
                    title: info.title,
                    round: app.round,
                    totalRounds: app.totalRounds,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({
    required this.value,
    required this.goal,
    required this.title,
    required this.round,
    required this.totalRounds,
  });

  final int value;
  final String goal;
  final String title;
  final int round;
  final int totalRounds;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0x55000000),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PixelLabel('ROUND $round/$totalRounds',
              size: 11, color: const Color(0xff4cc9f0)),
          const SizedBox(height: 8),
          PixelLabel(title, size: 16, color: Colors.white),
          const SizedBox(height: 4),
          PixelLabel(goal, size: 8, color: const Color(0xffc9c9d6)),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            key: ValueKey(value),
            tween: Tween(begin: 1.6, end: 1.0),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Text(
              '$value',
              style: const TextStyle(
                fontFamily: 'PressStart2P',
                fontSize: 110,
                color: Color(0xffffd166),
                shadows: [Shadow(color: Color(0xff141419), offset: Offset(6, 6))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
