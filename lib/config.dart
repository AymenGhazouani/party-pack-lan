/// Shared constants for Party Pack LAN.
library;

const String kAppName = 'Party Pack LAN';
const String kAppVersion = '1.0.0';

/// Port other phones listen on for lobby beacons.
const int kDiscoveryPort = 45678;

/// TCP port for the reliable control channel (lobby, rounds, scoring).
const int kControlPort = 45679;

/// UDP port for game inputs (client -> host) and snapshots (host -> client).
const int kGamePort = 45680;

const int kMaxPlayers = 4;
const int kProtocolVersion = 1;

/// World size for every mini-game (fixed-resolution viewport).
const double kWorldWidth = 960;
const double kWorldHeight = 540;
