import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import '../model/models.dart';

/// Client side of a hosted session: one TCP socket for reliable messages,
/// one UDP socket for inputs (out) and snapshots (in).
class ClientConnection {
  Socket? _tcp;
  RawDatagramSocket? _udp;
  int? playerId;
  String? hostIp;

  final StreamController<Map<String, dynamic>> _incoming =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<void> _done = StreamController<void>.broadcast();

  /// Decoded reliable messages from the host.
  Stream<Map<String, dynamic>> get incoming => _incoming.stream;

  /// Fires once when the host connection drops.
  Stream<void> get hostGone => _done.stream;

  Function(Map<String, dynamic> snapshot)? onSnapshot;

  Future<bool> connect({
    required String ip,
    required String name,
    required int avatarId,
  }) async {
    hostIp = ip;
    try {
      _tcp = await Socket.connect(ip, kControlPort,
          timeout: const Duration(seconds: 5));
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kGamePort,
          reuseAddress: true);
      _udp!.listen(_onUdp, cancelOnError: false);

      _tcp!.cast<List<int>>().transform(utf8.decoder).listen(
        _onChunk,
        onDone: _onDone,
        onError: (_) => _onDone(),
        cancelOnError: false,
      );

      _sendReliable({
        'type': 'hello',
        'name': name,
        'avatarId': avatarId,
        'v': kProtocolVersion,
      });
      return true;
    } catch (_) {
      await close();
      return false;
    }
  }

  final StringBuffer _buffer = StringBuffer();

  void _onChunk(String chunk) {
    _buffer.write(chunk);
    var content = _buffer.toString();
    var idx = content.indexOf('\n');
    while (idx != -1) {
      final line = content.substring(0, idx).trim();
      content = content.substring(idx + 1);
      if (line.isNotEmpty) {
        try {
          _incoming.add(jsonDecode(line) as Map<String, dynamic>);
        } catch (_) {}
      }
      idx = content.indexOf('\n');
    }
    _buffer.clear();
    _buffer.write(content);
  }

  void _onUdp(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _udp?.receive();
    if (dg == null) return;
    try {
      final data = jsonDecode(utf8.decode(dg.data));
      if (data is Map<String, dynamic> && data['type'] == 'snap') {
        onSnapshot?.call(data);
      }
    } catch (_) {}
  }

  void _onDone() {
    if (_done.isClosed) return;
    _done.add(null);
  }

  void _sendReliable(Map<String, dynamic> message) {
    _tcp?.add(utf8.encode('${jsonEncode(message)}\n'));
  }

  /// Send any reliable message to the host.
  void send(Map<String, dynamic> message) => _sendReliable(message);

  /// Throttle target: call at ~30 Hz during games.
  void sendInput(InputPacket input) {
    final ip = hostIp;
    final udp = _udp;
    if (ip == null || udp == null) return;
    final p = playerId ?? 0;
    final datagram = jsonEncode({
      'type': 'input',
      'p': p,
      ...input.toJson(),
    });
    udp.send(utf8.encode(datagram), InternetAddress(ip), kGamePort);
  }

  Future<void> close() async {
    try {
      await _tcp?.close();
      _tcp?.destroy();
    } catch (_) {}
    _tcp = null;
    _udp?.close(); // RawDatagramSocket.close() is synchronous
    _udp = null;
  }
}
