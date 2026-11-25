import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/game_screen.dart';
import 'screens/join_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/podium_screen.dart';
import 'screens/results_screen.dart';
import 'screens/title_screen.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final app = AppController();
  await app.init();
  runApp(PartyPackApp(app: app));
}

class PartyPackApp extends StatelessWidget {
  const PartyPackApp({super.key, required this.app});

  final AppController app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Party Pack LAN',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff16161e),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xffffd166),
          surface: Color(0xff26263a),
        ),
        fontFamily: 'PressStart2P',
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(child: _phaseScreen(app)),
            if (app.notice != null)
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xff2e2e44),
                        border: Border.all(color: const Color(0xffffd166), width: 2),
                      ),
                      child: Text(
                        app.notice!,
                        style: const TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          color: Color(0xffe3e3f1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _phaseScreen(AppController app) {
    switch (app.phase) {
      case AppPhase.title:
        return TitleScreen(app: app);
      case AppPhase.menu:
        return MenuScreen(app: app);
      case AppPhase.join:
        return JoinScreen(app: app);
      case AppPhase.lobby:
        return LobbyScreen(app: app);
      case AppPhase.game:
        return GameScreen(app: app);
      case AppPhase.results:
        return ResultsScreen(app: app);
      case AppPhase.podium:
        return PodiumScreen(app: app);
    }
  }
}
