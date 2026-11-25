import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';

/// Transport events emitted by [HostServer].
///
/// Sealed-ish union (plain maps to keep this simple):
/// - `{'t': 'conn', 'token': int, 'ip': String}` — new TCP client
/// - `{'t': 'msg', 'token': int, 'data': Map}` — decoded reliable message
/// - `{'t': 'disc', 'token': int, 'ip': String}` — client disconnected
/// - `{'t': 'input', 'ip': String, 'data': Map}` — decoded UDP input packet
class HostServer {
  ServerSocket? _tcp;
  RawDatagramSocket? _udp;
  final Map<int, Socket> _sockets = {};
  final Map<int, String> _ips = {};
  int _nextToken = 1;

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isRunning => _tcp != null;

  /// IPs of currently connected clients (for UDP snapshot delivery).
  List<String> get clientIps => _ips.values.toList();

  Future<String?> start() async {
    try {
      // shared/reuseAddress: a previous session that ended abruptly can
      // leave ports in TIME_WAIT; without these binds fail intermittently.
      _tcp = await ServerSocket.bind( InternetAddress.anyIPv4, kControlPort,
          shared: true);
      _tcp!.listen(_onSocket, onError: (_) {}, cancelOnError: false);
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kGamePort,
          reuseAddress: true);
      _udp!.listen(_onUdp, cancelOnError: false);
      return await _localIp();
    } catch (_) {
      await close();
      return null;
    }
  }

  Future<String?> _localIp() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('loopback')) continue;
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  void _onSocket(Socket socket) {
    final token = _nextToken++;
    _sockets[token] = socket;
    _ips[token] = socket.remoteAddress.address;
    _events.add({'t': 'conn', 'token': token, 'ip': socket.remoteAddress.address});

    final buffer = StringBuffer();
    socket.cast<List<int>>().transform(utf8.decoder).listen(
      (chunk) {
        buffer.write(chunk);
        var content = buffer.toString();
        var idx = content.indexOf('\n');
        while (idx != -1) {
          final line = content.substring(0, idx).trim();
          content = content.substring(idx + 1);
          if (line.isNotEmpty) _dispatchLine(token, line);
          idx = content.indexOf('\n');
        }
        buffer.clear();
        buffer.write(content);
      },
      onDone: () => _drop(token),
      onError: (_) => _drop(token),
      cancelOnError: false,
    );
  }

  void _dispatchLine(int token, String line) {
    try {
      _events.add({'t': 'msg', 'token': token, 'data': jsonDecode(line)});
    } catch (_) {
      // Ignore malformed lines.
    }
  }

  void _onUdp(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _udp?.receive();
    if (dg == null) return;
    try {
      final data = jsonDecode(utf8.decode(dg.data));
      _events.add({'t': 'input', 'ip': dg.address.address, 'data': data});
    } catch (_) {}
  }

  void _drop(int token) {
    final ip = _ips.remove(token);
    _sockets.remove(token)?.destroy();
    if (ip != null) {
      _events.add({'t': 'disc', 'token': token, 'ip': ip});
    }
  }

  /// Send a newline-delimited JSON message to every connected client.
  Future<void> broadcast(Map<String, dynamic> message) async {
    final line = utf8.encode('${jsonEncode(message)}\n');
    for (final socket in _sockets.values) {
      socket.add(line);
    }
    await _flush();
  }

  /// Send a message to one client only.
  Future<void> sendTo(int token, Map<String, dynamic> message) async {
    final socket = _sockets[token];
    if (socket == null) return;
    socket.add(utf8.encode('${jsonEncode(message)}\n'));
    await _flush();
  }

  /// UDP snapshot to all clients at [kGamePort].
  void broadcastSnapshot(Map<String, dynamic> snapshot) {
    final bytes = utf8.encode(jsonEncode(snapshot));
    for (final ip in _ips.values) {
      _udp?.send(bytes, InternetAddress(ip), kGamePort);
    }
  }

  /// Explicit flush — Socket writes are fire-and-forget otherwise.
  Future<void> _flush() async {
    for (final s in _sockets.values) {
      s.flush();
    }
  }

  Future<void> close() async {
    for (final socket in _sockets.values) {
      try {
        await socket.close();
        socket.destroy();
      } catch (_) {}
    }
    _sockets.clear();
    _ips.clear();
    await _tcp?.close();
    _tcp = null;
    _udp?.close(); // RawDatagramSocket.close() is synchronous
    _udp = null;
  }
}
