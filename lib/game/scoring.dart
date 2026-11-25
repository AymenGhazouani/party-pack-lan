import '../model/models.dart';

/// N, N-1, … 1 points for a best-first ranking. Ties should share points;
/// call sites pass pre-grouped tiers to [tiedPoints] or plain ids here.
List<PlacementResult> straightPoints(List<int> rankedPlayerIds) {
  final n = rankedPlayerIds.length;
  return [
    for (var i = 0; i < n; i++)
      PlacementResult(
        playerId: rankedPlayerIds[i],
        placement: i + 1,
        points: n - i,
      ),
  ];
}

/// Tiered ranking with ties: each tier is a group of player ids sharing a
/// placement. Points follow standard competition ranking ("1224").
List<PlacementResult> tiedPoints(List<List<int>> tiers) {
  final n = tiers.fold<int>(0, (sum, t) => sum + t.length);
  var rank = 1;
  final out = <PlacementResult>[];
  for (final tier in tiers) {
    final points = n - rank + 1;
    for (final id in tier) {
      out.add(PlacementResult(playerId: id, placement: rank, points: points));
    }
    rank += tier.length;
  }
  return out;
}

/// Co-op outcome: everyone scores the same. Success = [successPoints].
List<PlacementResult> coopPoints(List<int> playerIds, bool success) {
  final points = success ? 3 : 1;
  return [
    for (final id in playerIds)
      PlacementResult(playerId: id, placement: 1, points: points),
  ];
}

/// Team outcome (tug-of-war): winning side scores 4, losing side 1.
List<PlacementResult> teamPoints(List<int> winners, List<int> losers) {
  return [
    for (final id in winners)
      PlacementResult(playerId: id, placement: 1, points: 4),
    for (final id in losers)
      PlacementResult(playerId: id, placement: 2, points: 1),
  ];
}
