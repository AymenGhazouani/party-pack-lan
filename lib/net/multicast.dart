import 'package:flutter/services.dart';

const _channel = MethodChannel('partypack/net');

/// Android blocks LAN broadcast/multicast packets by default. Holding a
/// multicast lock while hosting or scanning lets beacons flow. Best-effort:
/// if the platform call fails we simply carry on.
Future<void> acquireMulticastLock() async {
  try {
    await _channel.invokeMethod('acquireMulticastLock');
  } catch (_) {}
}

Future<void> releaseMulticastLock() async {
  try {
    await _channel.invokeMethod('releaseMulticastLock');
  } catch (_) {}
}
