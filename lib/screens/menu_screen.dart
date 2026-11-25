import 'package:flutter/material.dart';

import '../config.dart';
import '../state/app_controller.dart';
import '../ui/backdrops.dart';
import '../ui/pixel_widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const PixelLabel('CHOOSE YOUR SIDE',
                          size: 10, color: Color(0xff4cc9f0)),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 380,
                        child: Column(
                          children: [
                            PixelButton(
                              label: 'HOST GAME',
                              face: const Color(0xffffd166),
                              fontSize: 18,
                              expand: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 22),
                              onTap: () => app.startHosting(),
                            ),
                            const SizedBox(height: 18),
                            PixelButton(
                              label: 'JOIN GAME',
                              face: const Color(0xff4cc9f0),
                              fontSize: 18,
                              expand: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 22),
                              onTap: app.goJoin,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const PixelLabel('EVERYONE ON THE SAME WI-FI',
                          size: 8, color: Color(0xff777788)),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                top: 14,
                child: IconButton(
                  onPressed: app.backToTitle,
                  icon: const Icon(Icons.arrow_back,
                      color: Color(0xffcfd2dc), size: 30),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 12,
                child: PixelLabel('v$kAppVersion',
                    size: 8, color: const Color(0xff555566)),
              ),
            ],
          ),
        );
      },
    );
  }
}
