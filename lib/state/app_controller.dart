import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio.dart';
import '../config.dart';
import '../game/game_registry.dart';
import '../model/models.dart';
import '../net/client_connection.dart';
import '../net/host_server.dart';
import '../net/lan_beacon.dart';
import '../net/network_session.dart';
import '../state/input_bus.dart';
import '../pixel/sprites.dart';

enum AppPhase { title, menu, join, lobby, game, results, podium }

/// Owns the whole app flow: prefs, LAN hosting/joining, lobby, rounds,
/// scoring, results and podium. Screens render [AppController.phase] and
/// call the action methods below.
class AppController extends ChangeNotifier {
  AppPhase phase = AppPhase.title;
  String? notice;

  // ---- local player / prefs -------------------------------------------------
  String playerName = 'Player';
  int avatarId = 0;
  bool _prefsReady = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    playerName = prefs.getString('playerName') ?? 'Player';
    avatarId = prefs.getInt('avatarId') ?? 0;
    _prefsReady = true;
    notifyListeners();
    Audio.init();
    Audio.playLobby();
  }

  void setPlayerName(String name) {
    playerName = name.trim().isEmpty ? 'Player' : name.trim();
    _savePrefs();
    notifyListeners();
  }

  /// Save without notifying listeners — used from widget dispose, where
  /// marking the tree dirty is illegal.
  void savePlayerNameQuiet(String name) {
    playerName = name.trim().isEmpty ? 'Player' : name.trim();
    _savePrefs();
  }

  void cycleAvatar(int delta) {
    avatarId = (avatarId + delta) % kAvatarColors.length;
    if (avatarId < 0) avatarId += kAvatarColors.length;
    _savePrefs();
    notifyListeners();
    Audio.select();
  }

  Future<void> _savePrefs() async {
    if (!_prefsReady) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playerName', playerName);
    await prefs.setInt('avatarId', avatarId);
  }

  // ---- session state ----------------------------------------------------------
  NetworkSession? session;
  HostServer? _hostServer;
  ClientConnection? _client;
  final DiscoveryService discovery = DiscoveryService();
  StreamSubscription<LobbyBeacon>? _scanSub;

  List<PlayerInfo> players = [];
  Map<int, int> totals = {};
  int totalRounds = 4;
  int round = 1;

  /// Host's picked game id; null means "random at round start".
  String? selectedGameId;

  int get myPlayerId => session?.myPlayerId ?? 1;
  bool get amHost => session?.isHost ?? false;
  bool get inSession => session != null;

  /// Host IP shown on the lobby screen so players can join manually.
  String hostIp = '';

  // join screen
  List<LobbyBeacon> scanResults = [];
  bool joining = false;
  String? joinError;

  // game / results
  GameInfo? activeGame;
  RoundResult? lastResult;
  bool get lastRoundIsFinal => round >= totalRounds;

  PlayerInfo? get me {
    for (final p in players) {
      if (p.id == myPlayerId) return p;
    }
    return null;
  }

  List<PlayerInfo> get podiumOrder {
    final sorted = [...players];
    sorted.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return sorted;
  }

  void _setPhase(AppPhase next) {
    phase = next;
    notifyListeners();
  }

  void _flash(String message) {
    notice = message;
    notifyListeners();
    Timer(const Duration(seconds: 4), () {
      notice = null;
      notifyListeners();
    });
  }

  void goMenu() {
    _setPhase(AppPhase.menu);
    Audio.playLobby();
  }

  void goJoin() {
    _setPhase(AppPhase.join);
    Audio.tap();
  }

  void backToTitle() {
    _setPhase(AppPhase.title);
    Audio.playLobby();
  }

  // ---- hosting ---------------------------------------------------------------
  Future<void> startHosting() async {
    final host = HostServer();
    final ip = await host.start();
    if (ip == null) {
      _flash('Could not open LAN ports $kControlPort/$kGamePort');
      return;
    }
    _hostServer = host;
    hostIp = ip;
    session = NetworkSession(isHost: true, myPlayerId: 1, host: host);
    players = [
      PlayerInfo(id: 1, name: playerName, avatarId: avatarId, isHost: true),
    ];
    totals = {1: 0};
    round = 1;
    selectedGameId = null;
    _wireHost();
    await discovery.startAnnouncing(
      hostName: "$playerName's lobby",
      playerCount: () => players.where((p) => p.connected).length,
      totalRounds: totalRounds,
    );
    _setPhase(AppPhase.lobby);
  }

  final Map<int, int> _tokenToPlayer = {};

  void _wireHost() {
    _hostServer!.events.listen((event) {
      switch (event['t']) {
        case 'msg':
          _onHostMessage(event['token'] as int,
              event['data'] as Map<String, dynamic>);
        case 'disc':
          _onHostDisconnect(event['token'] as int);
        case 'input':
          final data = event['data'] as Map<String, dynamic>;
          final playerId = (data['p'] as num?)?.toInt();
          if (playerId == null) break;
          final target = players.where((p) => p.id == playerId);
          if (target.isEmpty || !target.first.connected) break;
          session?.onInput
              ?.call(playerId, InputPacket.fromJson(data));
        default:
          break;
      }
    });
  }

  void _onHostMessage(int token, Map<String, dynamic> data) {
    switch (data['type']) {
      case 'hello':
        if (_tokenToPlayer.containsKey(token)) return;
        final used = players.map((p) => p.id).toList();
        var id = 2;
        while (used.contains(id)) {
          id++;
        }
        if (id > kMaxPlayers) {
          _hostServer!.sendTo(token, {
            'type': 'error',
            'message': 'Lobby is full',
          });
          return;
        }
        _tokenToPlayer[token] = id;
        final name = (data['name'] as String? ?? 'Player').trim();
        final avatar = data['avatarId'] as int? ?? 0;
        players = [
          ...players,
          PlayerInfo(
            id: id,
            name: name.isEmpty ? 'Player $id' : name,
            avatarId: avatar,
          ),
        ];
        totals = {...totals, id: 0};
        _hostServer!.sendTo(token, {
          'type': 'welcome',
          'playerId': id,
          'players': players.map((p) => p.toJson()).toList(),
          'round': round,
          'totalRounds': totalRounds,
        });
        _broadcastLobby();
      default:
        break;
    }
  }

  void _onHostDisconnect(int token) {
    final playerId = _tokenToPlayer.remove(token);
    if (playerId == null) return;
    players = [
      for (final p in players)
        if (p.id == playerId)
          PlayerInfo(
            id: p.id,
            name: p.name,
            avatarId: p.avatarId,
            isHost: false,
            connected: false,
            totalScore: p.totalScore,
          )
        else
          p,
    ];
    _broadcastLobby();
  }

  void _broadcastLobby() {
    final msg = _lobbyMessage();
    _hostServer?.broadcast(msg);
    _handleReliable(msg);
  }

  Map<String, dynamic> _lobbyMessage() => {
        'type': 'lobby',
        'players': players.map((p) => p.toJson()).toList(),
        'round': round,
        'totalRounds': totalRounds,
        'selectedGameId': selectedGameId,
      };

  // ---- joining ----------------------------------------------------------------
  void startScan() {
    stopScan();
    scanResults = [];
    discovery.startListening();
    _scanSub = discovery.beacons.listen((beacon) {
      scanResults = [
        ...scanResults.where((b) => b.address != beacon.address),
        beacon,
      ];
      notifyListeners();
    });
    notifyListeners();
  }

  void stopScan() {
    _scanSub?.cancel();
    _scanSub = null;
    discovery.stopListening();
  }

  Future<void> joinBeacon(LobbyBeacon beacon) => _join(beacon.address);

  Future<void> joinManual(String ip) => _join(ip.trim());

  Future<void> _join(String ip) async {
    joining = true;
    joinError = null;
    notifyListeners();

    final client = ClientConnection();
    final ok = await client.connect(
      ip: ip,
      name: playerName,
      avatarId: avatarId,
    );
    if (!ok) {
      joinError = 'Could not reach $ip — same Wi-Fi?';
      joining = false;
      notifyListeners();
      return;
    }
    _client = client;
    session = NetworkSession(
      isHost: false,
      host: null,
      client: client,
      myPlayerId: 0,
      hostIp: ip,
    );
    client.onSnapshot = (snap) => session?.onSnapshot?.call(snap);
    _wireClient();
    stopScan();
  }

  void _wireClient() {
    _client!.incoming.listen(_handleReliable);
    _client!.hostGone.listen((_) => _handleHostGone());
  }

  void _handleHostGone() {
    if (session == null) return;
    _teardown();
    _flash('Host left the session');
    _setPhase(AppPhase.menu);
    Audio.playLobby();
  }

  // ---- shared reliable-message handling ---------------------------------------
  void _handleReliable(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'lobby':
        players = (msg['players'] as List<dynamic>)
            .map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        round = msg['round'] as int? ?? round;
        totalRounds = msg['totalRounds'] as int? ?? totalRounds;
        selectedGameId = msg['selectedGameId'] as String?;
        notifyListeners();
      case 'welcome':
        session!.myPlayerId = msg['playerId'] as int;
        _client!.playerId = session!.myPlayerId;
        players = (msg['players'] as List<dynamic>)
            .map((e) => PlayerInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        round = msg['round'] as int? ?? 1;
        totalRounds = msg['totalRounds'] as int? ?? 4;
        joining = false;
        Audio.confirm();
        _setPhase(AppPhase.lobby);
      case 'countdown':
        final id = msg['gameId'] as String;
        activeGame = gameById(id);
        round = msg['round'] as int? ?? round;
        totalRounds = msg['totalRounds'] as int? ?? totalRounds;
        inputBus.reset();
        Audio.stopMusic();
        Audio.playGame();
        _setPhase(AppPhase.game);
      case 'roundEnd':
        lastResult = RoundResult.fromJson(msg);
        totals = Map<int, int>.from(lastResult!.totals);
        players = [
          for (final p in players)
            PlayerInfo(
              id: p.id,
              name: p.name,
              avatarId: p.avatarId,
              isHost: p.isHost,
              connected: p.connected,
              totalScore: totals[p.id] ?? p.totalScore,
            ),
        ];
        Audio.play(lastResult!.coOp
            ? (lastResult!.coOpSuccess ? 'win.wav' : 'lose.wav')
            : 'point.wav');
        _setPhase(AppPhase.results);
      case 'podium':
        _setPhase(AppPhase.podium);
        Audio.playPodium();
      case 'gotoLobby':
        round = msg['round'] as int? ?? (round + 1);
        players = [
          for (final p in players)
            PlayerInfo(
              id: p.id,
              name: p.name,
              avatarId: p.avatarId,
              isHost: p.isHost,
              connected: p.connected,
              totalScore: totals[p.id] ?? p.totalScore,
            ),
        ];
        Audio.playLobby();
        _setPhase(AppPhase.lobby);
      case 'playAgain':
        totals = {for (final p in players) p.id: 0};
        players = [
          for (final p in players)
            PlayerInfo(
              id: p.id,
              name: p.name,
              avatarId: p.avatarId,
              isHost: p.isHost,
              connected: p.connected,
            ),
        ];
        round = 1;
        Audio.playLobby();
        _setPhase(AppPhase.lobby);
      case 'toMenu':
        _teardown();
        _setPhase(AppPhase.menu);
        Audio.playLobby();
      case 'error':
        joinError = msg['message'] as String? ?? 'Error';
        joining = false;
        _flash(joinError!);
        notifyListeners();
      default:
        break;
    }
  }

  void _sendToAll(Map<String, dynamic> msg) {
    _hostServer?.broadcast(msg);
    _handleReliable(msg);
  }

  // ---- lobby actions -----------------------------------------------------------
  void setTotalRounds(int value) {
    if (!amHost) return;
    totalRounds = value;
    _broadcastLobby();
    Audio.select();
  }

  void selectGame(String? gameId) {
    if (!amHost) return;
    selectedGameId = gameId;
    _broadcastLobby();
    Audio.select();
  }

  GameInfo _pickGame() {
    if (selectedGameId != null) {
      return gameById(selectedGameId!) ?? kGames.first;
    }
    return kGames[Random().nextInt(kGames.length)];
  }

  void startRound() {
    if (!amHost) return;
    final game = _pickGame();
    _sendToAll({
      'type': 'countdown',
      'gameId': game.id,
      'round': round,
      'totalRounds': totalRounds,
      'seconds': 3,
    });
  }

  // ---- round finish (host computes via the game) --------------------------------
  /// Called by the hosting game instance once the round is decided.
  void finishRound({
    required String gameId,
    required List<PlacementResult> results,
    required bool coOpSuccess,
  }) {
    final coOp = activeGame?.mode == GameMode.coop;
    final updated = Map<int, int>.from(totals);
    for (final r in results) {
      updated[r.playerId] = (updated[r.playerId] ?? 0) + r.points;
    }
    totals = updated;
    final result = RoundResult(
      gameId: gameId,
      round: round,
      results: results,
      coOp: coOp,
      coOpSuccess: coOp ? coOpSuccess : false,
      totals: updated,
    );
    _sendToAll({
      'type': 'roundEnd',
      ...result.toJson(),
    });
  }

  void resultsNext() {
    if (!amHost) return;
    if (round >= totalRounds) {
      _sendToAll({'type': 'podium', 'totals': totals});
    } else {
      round += 1;
      _sendToAll({'type': 'gotoLobby', 'round': round});
    }
    Audio.tap();
  }

  void playAgain() {
    if (!amHost) return;
    _sendToAll({'type': 'playAgain'});
    Audio.tap();
  }

  void leaveToMenu() {
    if (amHost) {
      _sendToAll({'type': 'toMenu'});
      _teardown();
    } else {
      _teardown();
    }
    _setPhase(AppPhase.menu);
    Audio.playLobby();
  }

  Future<void> _teardown() async {
    stopScan();
    await discovery.stopAnnouncing();
    session?.unhook();
    await _hostServer?.close();
    _hostServer = null;
    await _client?.close();
    _client = null;
    session = null;
    players = [];
    totals = {};
    lastResult = null;
    activeGame = null;
    _tokenToPlayer.clear();
  }
}
