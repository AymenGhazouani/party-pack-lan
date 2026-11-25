import 'dart:convert';

class PlayerInfo {
  PlayerInfo({
    required this.id,
    required this.name,
    required this.avatarId,
    this.isHost = false,
    this.connected = true,
    this.totalScore = 0,
  });

  final int id;
  final String name;
  final int avatarId;
  bool isHost;
  bool connected;
  int totalScore;

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
        id: json['id'] as int,
        name: json['name'] as String? ?? 'Player',
        avatarId: json['avatarId'] as int? ?? 0,
        isHost: json['isHost'] as bool? ?? false,
        connected: json['connected'] as bool? ?? true,
        totalScore: json['totalScore'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarId': avatarId,
        'isHost': isHost,
        'connected': connected,
        'totalScore': totalScore,
      };
}

class PlacementResult {
  PlacementResult({
    required this.playerId,
    required this.placement,
    required this.points,
  });

  final int playerId;
  final int placement; // 1 = first. Co-op games use 1 for everyone.
  final int points;

  factory PlacementResult.fromJson(Map<String, dynamic> json) =>
      PlacementResult(
        playerId: json['id'] as int,
        placement: json['placement'] as int,
        points: json['points'] as int,
      );

  Map<String, dynamic> toJson() =>
      {'id': playerId, 'placement': placement, 'points': points};
}

class RoundResult {
  RoundResult({
    required this.gameId,
    required this.round,
    required this.results,
    required this.coOp,
    required this.coOpSuccess,
    required this.totals,
  });

  final String gameId;
  final int round;
  final List<PlacementResult> results;
  final bool coOp;
  final bool coOpSuccess; // only meaningful when coOp
  final Map<int, int> totals; // playerId -> session total after this round

  factory RoundResult.fromJson(Map<String, dynamic> json) => RoundResult(
        gameId: json['gameId'] as String,
        round: json['round'] as int,
        results: (json['results'] as List<dynamic>)
            .map((e) => PlacementResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        coOp: json['coOp'] as bool? ?? false,
        coOpSuccess: json['coOpSuccess'] as bool? ?? false,
        totals: (json['totals'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(int.parse(k), v as int)),
      );

  Map<String, dynamic> toJson() => {
        'gameId': gameId,
        'round': round,
        'results': results.map((r) => r.toJson()).toList(),
        'coOp': coOp,
        'coOpSuccess': coOpSuccess,
        'totals': totals.map((k, v) => MapEntry('$k', v)),
      };
}

/// Monotonic input packet sent by clients (and read locally on the host).
class InputPacket {
  const InputPacket({
    this.x = 0,
    this.y = 0,
    this.action = false,
    this.dash = false,
    this.mash = 0,
  });

  /// Normalized joystick axes in [-1, 1].
  final double x;
  final double y;

  /// Held action button (fire-brigade spray).
  final bool action;

  /// Held dash button (sumo). Host edge-detects.
  final bool dash;

  /// Monotonic counter of "mash" presses (tug-of-war).
  final int mash;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'act': action,
        'dash': dash,
        'mash': mash,
      };

  factory InputPacket.fromJson(Map<String, dynamic> json) => InputPacket(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        action: json['act'] as bool? ?? false,
        dash: json['dash'] as bool? ?? false,
        mash: json['mash'] as int? ?? 0,
      );
}

String encodeMessage(Map<String, dynamic> message) => jsonEncode(message);

Map<String, dynamic> decodeMessage(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
