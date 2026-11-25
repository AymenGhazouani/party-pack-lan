import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../ui/backdrops.dart';
import '../ui/pixel_widgets.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.app});

  final AppController app;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final TextEditingController _ip = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.app.startScan();
  }

  @override
  void dispose() {
    widget.app.stopScan();
    _ip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: StarfieldPainter()),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PixelLabel('FIND LAN LOBBIES',
                          size: 12, color: Color(0xffffd166)),
                      const SizedBox(height: 8),
                      const PixelLabel(
                        'HOST GAME ON ONE PHONE — EVERYONE ELSE JOINS HERE',
                        size: 7,
                        color: Color(0xff777788),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          children: [
                            // Discovered lobbies
                            Expanded(
                              flex: 6,
                              child: PixelPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (app.scanResults.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 8),
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xff4cc9f0),
                                              ),
                                            ),
                                          ),
                                        const PixelLabel('SCANNING…',
                                            size: 9,
                                            color: Color(0xff4cc9f0)),
                                        const Spacer(),
                                        IconButton(
                                          onPressed: app.startScan,
                                          icon: const Icon(Icons.refresh,
                                              color: Color(0xffcfd2dc)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: app.scanResults.isEmpty
                                          ? const Center(
                                              child: PixelLabel(
                                                'NO LOBBIES YET\n\nSTART HOSTING ON\nANOTHER PHONE!',
                                                size: 8,
                                                color: Color(0xff555566),
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount: app.scanResults.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(height: 8),
                                              itemBuilder: (_, i) {
                                                final b = app.scanResults[i];
                                                return _LobbyTile(
                                                  name: b.hostName,
                                                  ip: b.address,
                                                  players:
                                                      '${b.players}/${b.maxPlayers} PLAYERS',
                                                  rounds:
                                                      '${b.totalRounds} ROUNDS',
                                                  onTap: () =>
                                                      app.joinBeacon(b),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Manual IP entry
                            Expanded(
                              flex: 4,
                              child: PixelPanel(
                                color: const Color(0xff232338),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const PixelLabel('JOIN BY IP',
                                        size: 10,
                                        color: Color(0xffffd166)),
                                    const SizedBox(height: 10),
                                    const PixelLabel(
                                      'ENTER THE HOST IP SHOWN ON THE HOST LOBBY',
                                      size: 7,
                                      color: Color(0xff777788),
                                    ),
                                    const SizedBox(height: 12),
                                    PixelTextField(
                                      controller: _ip,
                                      hint: '192.168.x.x',
                                      fontSize: 11,
                                      maxLength: 15,
                                      keyboardType: TextInputType.url,
                                      onSubmitted: (_) =>
                                          app.joinManual(_ip.text),
                                    ),
                                    const SizedBox(height: 12),
                                    PixelButton(
                                      label: 'CONNECT',
                                      face: const Color(0xff4cc9f0),
                                      fontSize: 12,
                                      onTap: () => app.joinManual(_ip.text),
                                    ),
                                    if (app.joinError != null) ...[
                                      const SizedBox(height: 12),
                                      PixelLabel(
                                        app.joinError!,
                                        size: 7,
                                        color: const Color(0xffef476f),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: IconButton(
                  onPressed: () => app.goMenu(),
                  icon: const Icon(Icons.arrow_back,
                      color: Color(0xffcfd2dc), size: 30),
                ),
              ),
              if (app.joining)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xaa000000),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            color: Color(0xffffd166),
                          ),
                        ),
                        SizedBox(height: 18),
                        PixelLabel('CONNECTING…',
                            size: 12, color: Color(0xffffd166)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LobbyTile extends StatelessWidget {
  const _LobbyTile({
    required this.name,
    required this.ip,
    required this.players,
    required this.rounds,
    required this.onTap,
  });

  final String name;
  final String ip;
  final String players;
  final String rounds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xff2e2e44),
          border: Border.all(color: const Color(0xff141419), width: 3),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi, color: Color(0xff06d6a0), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelLabel(name.toUpperCase(),
                      size: 10, color: Colors.white),
                  const SizedBox(height: 5),
                  PixelLabel('$ip  •  $players  •  $rounds',
                      size: 7, color: const Color(0xff9a9aa8)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xffffd166), size: 30),
          ],
        ),
      ),
    );
  }
}
