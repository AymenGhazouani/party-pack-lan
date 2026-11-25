import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:party_pack_lan/game/game_registry.dart';
import 'package:party_pack_lan/game/sumo_push/sumo_push_game.dart';
import 'package:party_pack_lan/model/models.dart';
import 'package:party_pack_lan/net/network_session.dart';

double playerX(SumoPushGame game, int id) {
  final players = (game.buildSnapshot()['players'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final entry = players.firstWhere((e) => e['id'] == id);
  return (entry['x'] as num).toDouble();
}

void main() {
  testWidgets('host applies remote player input (p2 can move)', (tester) async {
    final session = NetworkSession(isHost: true, myPlayerId: 1);
    final roster = [
      PlayerInfo(id: 1, name: 'HOST', avatarId: 0, isHost: true, connected: true),
      PlayerInfo(id: 2, name: 'GUEST', avatarId: 3, connected: true),
    ];
    final game = SumoPushGame(
      session: session,
      roster: roster,
      round: 1,
      totalRounds: 1,
      gameInfo: sumoPush,
      onRoundFinish: (results, coOpSuccess) {},
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    await tester.pump();

    // Count down.
    for (var i = 0; i < 80 && !game.playing; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.playing, isTrue);

    final before = playerX(game, 2);
    game.remoteInputs[2] = const InputPacket(x: 1, y: 0);
    for (var i = 0; i < 30; i++) {
      game.simulate(1 / 60);
    }
    expect(playerX(game, 2), greaterThan(before));
  });
}
