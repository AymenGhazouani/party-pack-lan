import '../model/models.dart';
import 'client_connection.dart';
import 'host_server.dart';

/// Facade handed to mini-games: exactly the surface they need for syncing,
/// regardless of whether we host or joined someone else's game.
class NetworkSession {
  NetworkSession({
    required this.isHost,
    this.myPlayerId = 0,
    this.host,
    this.client,
    this.hostIp,
  });

  final bool isHost;
  int myPlayerId;
  final HostServer? host;
  final ClientConnection? client;
  final String? hostIp; // set on clients; shown in lobby/debug

  /// Client-side: called for every world snapshot received from the host.
  void Function(Map<String, dynamic> snapshot)? onSnapshot;

  /// Host-side: called for every UDP input datagram received from a client.
  void Function(int playerId, InputPacket input)? onInput;

  /// Detach game callbacks (round over, leaving session) so the discarded
  /// game instance is garbage collected instead of receiving snapshots.
  void unhook() {
    onSnapshot = null;
    onInput = null;
  }

  void sendInput(InputPacket input) => client?.sendInput(input);

  void broadcastSnapshot(Map<String, dynamic> snapshot) =>
      host?.broadcastSnapshot(snapshot);

  Future<void> close() async {
    await host?.close();
    await client?.close();
  }
}
