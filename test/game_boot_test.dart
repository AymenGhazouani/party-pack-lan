import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:party_pack_lan/game/game_registry.dart';
import 'package:party_pack_lan/game/sumo_push/sumo_push_game.dart';
import 'package:party_pack_lan/model/models.dart';
import 'package:party_pack_lan/net/network_session.dart';

void main() {
  testWidgets('sumo push boots, counts down and finishes a round',
      (tester) async {
    final session = NetworkSession(isHost: true, myPlayerId: 1);
    final roster = [
      PlayerInfo(id: 1, name: 'HOST', avatarId: 0, isHost: true, connected: true),
      PlayerInfo(id: 2, name: 'GUEST', avatarId: 3, connected: true),
    ];
    List<PlacementResult>? captured;
    final game = SumoPushGame(
      session: session,
      roster: roster,
      round: 1,
      totalRounds: 1,
      gameInfo: sumoPush,
      onRoundFinish: (results, coOpSuccess) {
        captured = results;
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    await tester.pump(); // let onLoad run

    // Fast-forward through the 3s countdown.
    for (var i = 0; i < 80 && !game.playing; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.playing, isTrue);

    // Nearly-expired timer forces the round to resolve.
    game.timeLeft = 0.05;
    for (var i = 0; i < 20 && captured == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(captured, isNotNull);
    expect(captured!.length, 2);
    // Timed-out survivors tie for first in a 2-player game.
    expect(captured!.every((r) => r.placement == 1 && r.points == 2), isTrue);
  });
}
