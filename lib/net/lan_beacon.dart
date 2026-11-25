import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import 'multicast.dart';

/// A lobby advertised on the LAN.
class LobbyBeacon {
  const LobbyBeacon({
    required this.hostName,
    required this.address,
    required this.players,
    required this.maxPlayers,
    required this.totalRounds,
  });

  final String hostName;
  final String address; // IP of the host device
  final int players;
  final int maxPlayers;
  final int totalRounds;

  String get playerSummary => '$players/$maxPlayers players';
}

/// UDP broadcast discovery: the host announces, everyone else listens.
///
/// Beacon datagrams look like `PPLAN1:{"n":"name","p":2,"m":4,"r":4,"v":1}`.
class DiscoveryService {
  static const String _magic = 'PPLAN1:';

  RawDatagramSocket? _listener;
  RawDatagramSocket? _announcer;
  final StreamController<LobbyBeacon> _found =
      StreamController<LobbyBeacon>.broadcast();
  Timer? _timer;

  /// Lobbies detected while listening. De-duplicate by address in the UI.
  Stream<LobbyBeacon> get beacons => _found.stream;

  Future<void> startListening() async {
    if (_listener != null) return;
    await acquireMulticastLock();
    try {
      _listener = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kDiscoveryPort,
        reuseAddress: true,
      );
      _listener!.broadcastEnabled = true;
      _listener!.listen(_onPacket);
    } catch (_) {
      // Discovery unsupported (e.g. missing permissions) — manual IP join
      // still works.
    }
  }

  Future<void> startAnnouncing({
    required String hostName,
    required int Function() playerCount,
    required int totalRounds,
  }) async {
    await stopAnnouncing();
    await acquireMulticastLock();
    try {
      _announcer = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _announcer!.broadcastEnabled = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final payload = jsonEncode({
          'n': hostName,
          'p': playerCount(),
          'm': kMaxPlayers,
          'r': totalRounds,
          'v': kProtocolVersion,
        });
        final datagram = utf8.encode(_magic + payload);
        _announcer!.send(datagram, InternetAddress('255.255.255.255'),
            kDiscoveryPort);
      });
    } catch (_) {}
  }

  Future<void> stop() => Future.wait([stopListening(), stopAnnouncing()]);

  Future<void> stopListening() async {
    _listener?.close();
    _listener = null;
    await releaseMulticastLock();
  }

  Future<void> stopAnnouncing() async {
    _timer?.cancel();
    _timer = null;
    _announcer?.close();
    _announcer = null;
    await releaseMulticastLock();
  }

  void _onPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _listener?.receive();
    if (dg == null) return;
    try {
      final data = utf8.decode(dg.data);
      if (!data.startsWith(_magic)) return;
      final json = jsonDecode(data.substring(_magic.length));
      _found.add(LobbyBeacon(
        hostName: json['n'] as String? ?? 'Lobby',
        address: dg.address.address,
        players: (json['p'] as num?)?.toInt() ?? 1,
        maxPlayers: (json['m'] as num?)?.toInt() ?? kMaxPlayers,
        totalRounds: (json['r'] as num?)?.toInt() ?? 4,
      ));
    } catch (_) {
      // Ignore malformed packets.
    }
  }

  void dispose() {
    _timer?.cancel();
    _listener?.close();
    _announcer?.close();
    _found.close();
  }
}
