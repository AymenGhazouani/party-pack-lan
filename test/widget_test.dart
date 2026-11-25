import 'package:flutter_test/flutter_test.dart';

import 'package:party_pack_lan/game/scoring.dart';
import 'package:party_pack_lan/model/models.dart';

void main() {
  group('scoring', () {
    test('straightPoints awards N..1', () {
      final results = straightPoints([10, 20, 30, 40]);
      expect(results.map((r) => r.points), [4, 3, 2, 1]);
      expect(results.map((r) => r.placement), [1, 2, 3, 4]);
    });

    test('tiedPoints shares placements and uses competition ranking', () {
      final results = tiedPoints([
        [1, 2], // tied for first
        [3], // third
        [4, 5], // tied for fourth (no points left in a 5-player race)
      ]);
      expect(results.where((r) => r.placement == 1).length, 2);
      final third = results.firstWhere((r) => r.playerId == 3);
      expect(third.placement, 3);
      expect(third.points, 3); // 5 - 3 + 1
      final fourth = results.where((r) => r.placement == 4);
      expect(fourth.length, 2);
      expect(fourth.first.points, 2); // 5 - 4 + 1
    });

    test('coopPoints gives everyone the same reward', () {
      final win = coopPoints([1, 2], true);
      final lose = coopPoints([1, 2], false);
      expect(win.every((r) => r.points == 3), isTrue);
      expect(lose.every((r) => r.points == 1), isTrue);
    });

    test('teamPoints gives winners 4 and losers 1', () {
      final results = teamPoints([1, 3], [2, 4]);
      expect(results.where((r) => [1, 3].contains(r.playerId)).every((r) => r.points == 4),
          isTrue);
      expect(results.where((r) => [2, 4].contains(r.playerId)).every((r) => r.points == 1),
          isTrue);
    });
  });

  group('RoundResult', () {
    test('json roundtrip preserves totals and flags', () {
      final original = RoundResult(
        gameId: 'sumo_push',
        round: 2,
        results: [
          PlacementResult(playerId: 1, placement: 1, points: 4),
          PlacementResult(playerId: 2, placement: 2, points: 2),
        ],
        coOp: false,
        coOpSuccess: false,
        totals: {1: 8, 2: 3},
      );
      final decoded = RoundResult.fromJson(original.toJson());
      expect(decoded.round, 2);
      expect(decoded.totals, {1: 8, 2: 3});
      expect(decoded.results.length, 2);
      expect(decoded.coOp, isFalse);
    });
  });

  group('InputPacket', () {
    test('json roundtrip', () {
      const packet = InputPacket(x: 0.5, y: -1, action: true, dash: false, mash: 42);
      final decoded = InputPacket.fromJson(packet.toJson());
      expect(decoded.x, closeTo(0.5, 1e-9));
      expect(decoded.y, closeTo(-1, 1e-9));
      expect(decoded.action, isTrue);
      expect(decoded.mash, 42);
    });
  });
}
