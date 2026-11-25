import 'package:flutter/material.dart';

import '../config.dart';
import '../state/app_controller.dart';
import '../ui/avatar_view.dart';
import '../ui/backdrops.dart';
import '../ui/pixel_widgets.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.app});

  final AppController app;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.app.playerName);

  @override
  void dispose() {
    widget.app.savePlayerNameQuiet(_name.text);
    _name.dispose();
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  child: Row(
                    children: [
                      // Logo block
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PixelLabel('LOCAL CO-OP',
                                size: 10, color: const Color(0xff4cc9f0)),
                            const SizedBox(height: 10),
                            const Text(
                              'PARTY\nPACK',
                              style: TextStyle(
                                fontFamily: 'PressStart2P',
                                fontSize: 56,
                                height: 1.15,
                                color: Color(0xffffd166),
                                shadows: [
                                  Shadow(color: Color(0xff141419), offset: Offset(5, 5)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffef476f),
                                    border: Border.all(
                                        color: const Color(0xff141419), width: 3),
                                  ),
                                  child: const Text(
                                    'LAN',
                                    style: TextStyle(
                                      fontFamily: 'PressStart2P',
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const PixelLabel('v$kAppVersion',
                                    size: 8, color: Color(0xff777788)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const PixelLabel('2–4 PLAYERS  •  SAME WI-FI',
                                size: 9, color: Color(0xffcfd2dc)),
                          ],
                        ),
                      ),
                      // Player setup panel
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: PixelPanel(
                            color: const Color(0xff26263a),
                            child: SizedBox(
                              width: 300,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const PixelLabel('YOUR PLAYER',
                                      size: 10, color: Color(0xff4cc9f0)),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _AvatarArrow(
                                        icon: Icons.chevron_left,
                                        onTap: () => app.cycleAvatar(-1),
                                      ),
                                      const SizedBox(width: 14),
                                      Transform.translate(
                                        offset: const Offset(0, 2),
                                        child: AvatarView(
                                            avatarId: app.avatarId, scale: 6),
                                      ),
                                      const SizedBox(width: 14),
                                      _AvatarArrow(
                                        icon: Icons.chevron_right,
                                        onTap: () => app.cycleAvatar(1),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  PixelTextField(
                                    controller: _name,
                                    hint: 'NAME',
                                    maxLength: 12,
                                    onSubmitted: app.setPlayerName,
                                  ),
                                  const SizedBox(height: 16),
                                  PixelButton(
                                    label: 'START',
                                    face: const Color(0xffffd166),
                                    expand: true,
                                    fontSize: 16,
                                    onTap: () {
                                      app.setPlayerName(_name.text);
                                      app.goMenu();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _AvatarArrow extends StatelessWidget {
  const _AvatarArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xffffd166), size: 44),
      iconSize: 44,
    );
  }
}
